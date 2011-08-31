#!/usr/bin/env perl

=head1 NAME

SBG::Complex - Represents one solution to the problem of assembling a complex

=head1 SYNOPSIS

 use SBG::Complex;


=head1 DESCRIPTION

A state-holder for L<SBG::Traversal>.  L<SBG::Assembler> uses L<SBG::Complex> to
hold state-information while L<SBG::Traversal> is traversing an L<SBG::Network>.

In short, an L<SBG::Complex> is one of many
solutions to the protein complex assembly problem for a give set of proteins.

=head1 SEE ALSO

L<SBG::Traversal>

=cut

package SBG::Complex;
use Moose;

with qw(
    SBG::Role::Clonable
    SBG::Role::Scorable
    SBG::Role::Storable
    SBG::Role::Transformable
    SBG::Role::Versionable
    SBG::Role::Writable
);

use overload (
    '""'     => 'stringify',
    fallback => 1,
);

use Scalar::Util qw/refaddr/;
use Moose::Autobox;
use autobox::List::Util;
use List::MoreUtils qw/mesh uniq/;
use Module::Load;
use Carp;

use PDL::Lite;
use PDL::Core qw/pdl squeeze zeroes sclr/;
use Statistics::Lite qw/stddev/;

use Log::Any qw/$log/;
use bignum;    # qw/inf/;

use Algorithm::Combinatorics qw/variations/;
use Bio::Tools::Run::Alignment::Clustalw;

use SBG::Types qw/$pdb41/;
use SBG::U::List
    qw/interval_overlap intersection mean min max median sum flatten swap between cartesian_product/;
use SBG::U::RMSD;
use SBG::U::iRMSD;                # qw/irmsd/;
use SBG::STAMP;                   # qw/superposition/
use SBG::Superposition::Cache;    # qw/superposition/;
use SBG::DB::res_mapping;         # qw/query aln2locations/;
use SBG::U::DB qw/chain_case/;
use SBG::Run::PairedBlast qw/gi2pdbid/;
use SBG::Run::pdbseq qw/pdbseq/;
use SBG::Run::naccess qw/buried/;
use SBG::Run::qcons qw/qcons/;
use SBG::U::Map qw/tdracc2desc/;

# Complex stores these data structures
use SBG::Superposition;
use SBG::Model;
use SBG::Interaction;

# For deriving a network from the Complex
use SBG::Seq;
use SBG::Node;
use SBG::Network;

# Default domain representation
use SBG::Domain::Sphere;

# Get CA representation for backbone RMSD
use SBG::Domain::Atoms;

use SBG::U::CartesianPermutation;

use SBG::Run::pdbc qw/pdbc/;

=head2 modelid

 Function: 
 Example : 
 Returns : 
 Args    : 

Convenience label

=cut

has 'modelid' => (
    is  => 'rw',
    isa => 'Str',
);

=head2 targetid

The label / accession / idenftifier for the complex we are trying to build

=cut

has 'targetid' => (
    is  => 'rw',
    isa => 'Str',
);

=head2 target

For benchmarking the complex representing the native structure can be provided.

=cut

has 'target' => (
    is  => 'rw',
    isa => 'Maybe[SBG::Complex]',
);

has 'networkid' => (
    is  => 'rw',
    isa => 'Int',
);

# Cluster, for duplicate complexes
has 'class' => (
    is  => 'rw',
    isa => 'Str',
);

=head2 name

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut

has 'name' => (
    is  => 'rw',
    isa => 'Str',
);

# TODO better as a role 'Clearable', which iterates all attributes and checks 'has_clearer' and calls it.
sub clear {
    my ($self) = @_;
    $self->clear_description();
    $self->clear_vmdclashes();
    $self->clear_homology();
    $self->clear_score();
    $self->clear_score_weights();
    $self->clear_scores();
    $self->clear_modelled_coords();
    $self->clear_correspondance();
    $self->clear_network();
    $self->clear_globularity();
    $self->clear_buried_area();

}

=head2 description

Text description of the molecule. Extracted from the PDB entry using C<pdb> from L<SBG::STAMP>.

Note, this is not the 'descriptor' (that's in L<SBG::DomainI> )

=cut

has 'description' => (
    is         => 'rw',
    isa        => 'Maybe[Str]',
    lazy_build => 1,
    clearer    => 'clear_description',
);

sub _build_description {
    my ($self) = @_;
    my $target = $self->targetid;
    return unless $target;
    my ($pdbid, $tdrid);
    ($pdbid) = $target =~ /$pdb41/;
    my $desc;
    if ($pdbid) {

        # Looks like a PDB ID
        my $pdbc = pdbc($target);
        $desc = $pdbc->{header};
    }
    elsif ($target =~ /^\d{3}$/) {
        $desc = tdracc2desc($target);
    }
    return $desc if $desc;
}

=head2 objtype

 Function: Type of L<SBG::DomainI> object to use for clash detection
 Example : 
 Returns : 
 Args    : 
 Default : 'SBG::Domain::Sphere'

=cut

has 'objtype' => (
    is      => 'ro',
    isa     => 'ClassName',
    default => 'SBG::Domain::Sphere',
);

# ClassName does not validate if the class isn't already loaded. Preload it here
before 'objtype' => sub {
    my ($self, $classname) = @_;
    Module::Load::load($classname);
};

=head2 interactions

L<SBG::Interaction> objects used to create this complex. Indexed by the
B<primary_id> of the interaction.

=cut

has 'interactions' => (
    isa     => 'HashRef[SBG::Interaction]',
    is      => 'ro',
    lazy    => 1,
    default => sub { {} },
);

sub pdbids {
    my ($self) = @_;
    my $iactions = $self->interactions->values;
    my $pdbids = $iactions->map(sub { $_->pdbid });
    my $uniq = [ uniq @$pdbids ];
    return wantarray ? @$uniq : $uniq;
}

=head2 superpositions

L<SBG::Superposition> objects used to link structural homologs. Indexed by the
L<SBG::Node> that was newly added to the complex, as there may be many partners
to a given domain. Even though it is actually the partner domain that actually
gets superimposed onto the existing reference domain.

TODO DOC diagram

=cut

has 'superpositions' => (
    isa     => 'HashRef[SBG::Superposition]',
    is      => 'ro',
    lazy    => 1,
    default => sub { {} },
);

=head2 ncycles

 Function: Number of ring closures modelled by known interaction templates
 Example : 
 Returns : 
 Args    : 



=cut

has 'ncycles' => (
    is      => 'rw',
    default => sub {0},
);

=head2 clashes

Fractional overlap/clash of each domain when it was added to the complex. This
is not updated when subsequent domains are added. This has the nice side-effect
that overlaps are not double-counted. Each domain stores the clashes it
encounted at the time it was added.

E.g attach(A), attach(B), attach(C). If A and C clash, A wont know about it,
but C will have saved it, having been added subsequently.

Indexed by the L<SBG::Node> creating the clashes when it was added.

TOOD prefer to call this 'overlaps'

=cut

has 'clashes' => (
    isa     => 'HashRef[Num]',
    is      => 'ro',
    lazy    => 1,
    default => sub { {} },
);

# TODO each clash should be saved in the 'scores' hash of the Superposition

# Clashes, as defined by VMD, all-atom, as a percent
# Should not be much more than 1.5
has 'vmdclashes' => (
    is         => 'rw',
    isa        => 'Maybe[Num]',
    lazy_build => 1,
    clearer    => 'clear_vmdclashes',
);
use SBG::Run::vmdclashes;

sub _build_vmdclashes {
    my ($self,) = @_;
    my $res = SBG::Run::vmdclashes::vmdclashes($self) or return;
    return $res->{pcclashes};
}

=head2 models

 Function: Maps accession number of protein components to L<SBG::Model> model.
 Example : $cmplx->set('RRP43',
               new SBG::Model(query=>$myseq, subject=>$template_domain))
 Returns : The one L<SBG::Domain> modelling the protein, if any
 Args    : display_id

Indexed by display_id of L<SBG::Node> modelled by this L<SBG::Model>

=cut

has 'models' => (
    isa     => 'HashRef[SBG::Model]',
    is      => 'ro',
    lazy    => 1,
    default => sub { {} },
);

# Includes multiple representations, sorted by name/template
# NB keys() sorts by the ACC of the components, this sorts by their gene/label
sub all_models {
    my ($self,) = @_;
    my $interactions = $self->interactions->values;
    my $models = $interactions->map(sub { $_->models->flatten });
    $models = [
        sort {
            ($a->input . '/' . $a->subject) cmp($b->input . '/' . $b->subject)
            } @$models
    ];
    return $models;
}

# Assumes all models (i.e. multiple representatives per component)
sub chain_of {
    my ($self, %ops) = @_;
    our $labels = [ 'A' .. 'Z', 'a' .. 'z', 0 .. 9 ];
    my $index = 0;
    my $map   = {};
    $map->{$_} = $labels->[ $index++ % @$labels ]
        for $self->all_models->flatten;
    my $key = $ops{model};

    # Though this could also be the 'structure/domain/subject'
    # or the 'query/input/component'
    return $map->{$key};
}

=head2 symmetry

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut

has 'symmetry' => (is => 'rw',);

# TOOD DEL
use Data::Dumper;

has 'homology' => (
    is         => 'rw',
    isa        => 'ArrayRef[Int]',
    lazy_build => 1,
    clearer    => 'clear_homology',
);

sub _build_homology {
    my ($self,) = @_;
    my @cc = $self->symmetry->flatten;

    # The components actually being modelled in this complex, sorted by class,
    # since we are about to generate permutations of each class. The order of the
    # classes in @cc must be the same as the order of classes in $model I.e. if
    # class [B E] is first in @cc, then any B or E present must also be first in
    # $model
    my $keys = $self->keys;

    # Model components present, grouped by class
    my $model = [ map { scalar _members_by_class($_, $keys) } @cc ];

    # Flat list
    my @model = flatten $model;

    # Counts per class
    my $kclass = $model->map(sub { $_->length });

    # Number of members in each class, e.g. [1,3,2,1]
    return $kclass;
}

# The order of these keys must match the weights
has '+score_keys' => (
    default => sub {
        [   qw/pcclashes/,    # % all-atom clashes
            qw/pcdoms/,       # % of modelled components (of target)
            qw/mniactions/,   # # of interactions in model
            qw/pciactions/,   # % of modelled interactions (of target)
            qw/mseqlen/,      # Length of sequence modelled, over all proteins
            qw/pcseqlen/,     # % of sequence length coverage
            qw/nsources/,     # Number of PDB IDs over all templates used
            qw/pcburied/,     # % of SAS buried in complex
            qw/glob/,         # Globularity of complex [0:1]
            qw/scmax/,
            qw/scmed/,

            #    qw/scmin/,
            qw/idmax idmed idmin/,
            qw/ifacelenmax ifacelenmed ifacelenmin/,
            qw/iweightmax iweightmed iweightmin/,
            qw/seqcovermax seqcovermed seqcovermin/,
        ];
    },
);

# Final values is the constant
has '+score_weights' => (

    # Weight derived from training set
    #default => sub { pdl qw/
    #    1.0002784 -0.2046164  2.7741565 0.16234106 0.0022509768  -0.120098 -2.0390062 -0.32646872 -0.084590743  2.0155693   -2.62743 -0.055864886   0.193755 0.0080261051 0.030088151 -0.026983958 -0.032871555 0.21712407 -0.30196551 -0.24303391 0.0089509951 0.060238428 0.05075979  47.827834
    #    /},

    # Weights from entire set (training + test sets)
    default => sub {
        pdl qw/
            0.18339077 -0.25231889   2.797613 0.15700415 0.0046757956 -0.10488408 -0.4795089 -0.26835171 -0.059896217  1.4270931 -2.3454635 0.0064867146 0.18846124 0.01793003 -0.015299134 0.023561227 -0.054708354 0.036664054 -0.28909752 -0.21574682 -0.021124081 0.099562617 0.0085258907  55.099234
            /;
    },

);

# Override from Role::Scorable
sub _build_scores {
    my ($model) = @_;
    my $stats = {};
    $log->debug($model);

    $stats->{mid}   = $model->modelid();
    $stats->{tid}   = $model->targetid();
    $stats->{tdesc} = $model->description;

    # Number of Components that we were trying to model
    my @tdoms  = flatten $model->symmetry;
    my $tndoms = @tdoms;
    $stats->{tndoms} = $tndoms;

    # Number of domains modelled
    my $dommodels = $model->models->values;
    my $mndoms = $stats->{mndoms} = keys %{ $model->models };

    # Percentage of component coverage, e.g. 3/5 components => 60
    $stats->{pcdoms} = 100.0 * $mndoms / $tndoms;

    # Number of interactions modelled
    my $mniactions = $stats->{mniactions} = keys %{ $model->interactions };

    $log->debug("mniactions $mniactions");

    my $target = $model->target();

    # Number of interactions to be modelled in target
    my $tniactions =
        defined($target) ? $model->target->network->edges : 'nan';
    $stats->{tniactions} = $tniactions;
    $stats->{pciactions} =
        defined($target) ? 100.0 * $mniactions / $tniactions : 'nan';

    # TODO need to grep for defined($_) ? (also for n_res ? )
    my $ids = $dommodels->map(sub { $_->scores->at('seqid') });
    $stats->{idmin} = min $ids;
    $stats->{idmax} = max $ids;
    $stats->{idmed} = median $ids;

    # Model: interactions
    my $mias = $model->interactions->values;

    my $avg_seqids = $mias->map(sub { $_->scores->at('avg_seqid') });

    $stats->{n0}   = $avg_seqids->grep(sub { between($_, 0,   40) })->length;
    $stats->{n40}  = $avg_seqids->grep(sub { between($_, 40,  60) })->length;
    $stats->{n60}  = $avg_seqids->grep(sub { between($_, 60,  80) })->length;
    $stats->{n80}  = $avg_seqids->grep(sub { between($_, 80,  100) })->length;
    $stats->{n100} = $avg_seqids->grep(sub { between($_, 100, 101) })->length;

    # Number of residues in contact in an interaction, averaged between 2
    # interfaces.
    my $nres = $mias->map(sub { $_->scores->at('avg_n_res') });
    $stats->{ifacelenmin} = min $nres;
    $stats->{ifacelenmax} = max $nres;
    $stats->{ifacelenmed} = median $nres;

    # Docking, when used
    my $docked =
        $mias->map(sub { $_->scores->at('docking') })->grep(sub {defined});

    $stats->{dockmin} = min $docked;
    $stats->{dockmax} = max $docked;
    $stats->{dockmed} = median $docked;
    $stats->{'ndockless'} = $docked->grep(sub { $_ && $_ < 1386 })->length;
    $stats->{ndockgreat} = $docked->grep(sub { $_ && $_ >= 1386 })->length;

    # For each score less than 2000, penalize by the diff/1000
    # E.g. each score of 1750 is penalized by (2000-1750)/1000 => .25
    $stats->{dockpenalty} = $docked->map(sub { (2000 - $_) / 1000.0 })->sum;

    # Interprets, when available
    my $ipts = $mias->map(sub { $_->scores->at('interpretsz') });
    $stats->{iptsmin} = min $ipts;
    $stats->{iptsmax} = max $ipts;
    $stats->{iptsmed} = median $ipts;

    # Number of template PDB structures used in entire model
    # TODO belongs in SBG::Complex
    my $idomains = $mias->map(sub     { $_->domains->flatten });
    my $ipdbs    = $idomains->map(sub { $_->file });
    my $nsources = scalar List::MoreUtils::uniq $ipdbs->flatten;
    $stats->{nsources} = $nsources;

    # This is the sequence from the structural template used
    my $mseqlen = $dommodels->map(sub { $_->subject->seq->length })->sum;
    $stats->{mseqlen} = $mseqlen;

    # Length of the sequences that we were trying to model, original inputs
    # TODO DEL workaround for not having 'input' set for docking templates
    my $inputs = $dommodels->map(sub { $_->input || $_->query });
    my $tseqlen = $inputs->map(sub { $_->length })->sum;
    $stats->{tseqlen} = $tseqlen;

    # Percentage sequence coverage by the complex model
    my $pcseqlen = 100.0 * $mseqlen / $tseqlen;
    $stats->{pcseqlen} = $pcseqlen;

    # Sequence coverage per domain
    my $pdomcovers = $dommodels->map(sub { $_->coverage() });
    $stats->{seqcovermin} = min $pdomcovers;
    $stats->{seqcovermax} = max $pdomcovers;
    $stats->{seqcovermed} = median $pdomcovers;

    # Edge weight, generally the seqid
    my $weights = $mias->map(sub { $_->weight });

    # Average sequence identity of all the templates.
    # NB linker domains are counted multiple times.
    # Given a hub proten and three interacting spoke proteins, there are not 4
    # values for sequence identity, but rather 2*(3 interactions) => 6
    $stats->{iweightmin} = min $weights;
    $stats->{iweightmax} = max $weights;
    $stats->{iweightmed} = median $weights;

    # Linker superpositions required to build model by overlapping dimers
    my $superpositions = $model->superpositions->values;

    # Sc scores of all superpositions done
    my $scs = $superpositions->map(sub { $_->scores->at('Sc') });
    $stats->{scmin} = min $scs;
    $stats->{scmax} = max $scs;
    $stats->{scmed} = median $scs;

    # Globularity of entire model
    $stats->{glob} = $model->globularity();

    $stats->{pcburied} = $model->buried_area() || 'NaN';

    $stats->{pcclashes} = $model->vmdclashes();

    # Fraction overlaps between domains for each new component placed, averages
    my $overlaps = $model->clashes->values;
    $stats->{olmin} = min $overlaps;
    $stats->{olmax} = max $overlaps;
    $stats->{olmed} = median $overlaps;

    # Number of closed rings in modelled structure, using known interfaces
    $stats->{ncycles} = $model->ncycles();

    my $homology = $model->homology;
    my $present_homology = $homology->grep(sub { $_ > 0 });
    $stats->{homo} = $present_homology->length == 1 ? 1 : 0;
    $stats->{homology} = $present_homology->join('-');

    # subjective level of difficulty
    # TODO DEL
    $stats->{difficulty} = 0;

    #    print Dumper $stats;
    #    exit;

    # Format any objects/complex numbers as simple numbers again
    foreach my $key (keys %$stats) {
        if (ref($stats->{$key}) =~ /^Math::Big/) {
            $stats->{$key} = sprintf "%g", $stats->{$key}->numify();
        }
    }

    $log->debug(Dumper $stats);

    return ($stats);
}    # _build_scores

###############################################################################

=head2 domains

 Function: Extracts just the Domain objects from the Models in the Complex
 Example : 
 Returns : ArrayRef[SBG::DomainI]
 Args    : 

Order of domains is sorted alphabetically

=cut

sub domains {
    my ($self, $keys, $map) = @_;

    # Order of models attribute
    $keys ||= $self->keys;
    return unless @$keys;

    if (defined $map) {
        $keys = $keys->map(sub { $map->{$_} || $_ });
    }
    my $models  = $keys->map(sub   { $self->get($_) });
    my $domains = $models->map(sub { $_->structure });
    return $domains;

}    # domains

=head2 count

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut

sub count {
    my ($self,) = @_;
    return $self->models->keys->length;

}    # count

=head2 size

 Function: 
 Example : 
 Returns : 
 Args    : 

Alias to L<count>

=cut

sub size {
    my ($self,) = @_;
    return $self->count();

}    # size

sub seqs {
    my ($self) = @_;
    return $self->domains()->map(sub { $_->seq() });
}

=head2 seqlen
=cut

sub seqlen {
    my ($self) = @_;
    my $seqs = $self->seqs();
    return $seqs->map(sub { $_->length })->sum();

}

=head2 set/get/keys

 Function: 
 Example : 
 Returns : 
 Args    : 

Shouldn't be necessary, but neither L<Moose::Autobox> nor
L<MooseX::AttributeHelpers> create attributes that are instances of their own
class. I.e. neither 'handles' nor 'provides' are useful.

=cut

sub set {
    my $self = shift;
    return $self->models->put(@_);
}    # set

sub get {
    my $self = shift;
    return $self->models->at(@_);
}

# Order keys is sorted alphabetically (by the component ACC)
sub keys {
    my $self = shift;
    return $self->models->keys->sort;
}

# Mapping to names used to correspond to another structure
has 'correspondance' => (
    is      => 'rw',
    isa     => 'HashRef[Str]',
    default => sub { {} },
    clearer => 'clear_correspondance',
);

=head2 modelled_coords

 Function: 
 Example : 
 Returns : 
 Args    : 

To get the whole set in two dimensions;
my $modelled_coords = $complex->modelled_coords();
# Array of coordinate sets
my $values = $modelled_coords->values;
# Multidimensional piddle
my $coords = pdl($values);
# Flatten into 2D
$coords = $coords->clump(1,2) if $coords->dims == 3;
# Do something with $coords
print SBG::U::RMSD::centroid($coords);

=cut

has 'modelled_coords' => (
    is         => 'rw',
    lazy_build => 1,
    clearer    => 'clear_modelled_coords',
);

sub _build_modelled_coords {
    my ($self)          = @_;
    my $modelled_coords = {};
    my $keys            = $self->keys;

    foreach my $key (@$keys) {
        my $dommodel = $self->get($key);
        my $aln      = $dommodel->aln();
        if ($aln) {
            my ($modelled, $native) = $self->_coords_from_aln($aln, $key)
                or return;
            $modelled_coords->{$key} = $modelled;
        }
        else {

            # Clone the domain using the CA representation
            # Transformation will be retained
            my $dom      = $dommodel->structure;
            my $domatoms = SBG::Domain::Atoms->new(%$dom);
            $modelled_coords->{$key} = $domatoms->coords;
        }
    }

    return $modelled_coords;

}    # _build_modelled_coords

=head2 coords

 Function: 
 Example : 
 Returns : 
 Args    : 


TODO Belongs in DomSetI

=cut

sub coords {
    my ($self, @cnames) = @_;

    # Only consider common components
    @cnames = ($self->models->keys) unless @cnames;
    @cnames = flatten(@cnames);

    my @aslist = map { $self->get($_)->structure->coords } @cnames;
    my $coords = pdl(@aslist);

    # Clump into a 2D matrix, if there is a 3rd dimension
    # I.e. normally have an outer dimension representing individual domains.
    # Then each domain is a 2D matrix of coordinates
    # This clumps the whole set of domains into a single matrix of coords
    $coords = $coords->clump(1, 2) if $coords->dims == 3;
    return $coords;

}    # coords

=head2 add_model

 Function: 
 Example : 
 Returns : 
 Args    : L<SBG::Model>


=cut

sub add_model {
    my ($self, @models) = @_;
    $self->models->put($_->query, $_) for @models;
}    # add_model

=head2 network

 Function: Derive a new L<SBG::Network> from this complex
 Example : 
 Returns : L<SBG::Network>
 Args    : NA

NB cannot simply call L<Network::subgraph>, as we only want specific
interactions for given nodes, not all interaction between two nodes, as
B<subgraph> would tend to do it.  Nor is there a way to remove interactions from
a graph, so we built it here, as needed.

=cut

has 'network' => (
    is         => 'rw',
    isa        => 'SBG::Network',
    lazy_build => 1,
    clearer    => 'clear_network',
);

sub _build_network {
    my ($self) = @_;

    my $net = SBG::Network->new;

    # Go through %{ $self->interactions }
    foreach my $i (@{ $self->interactions->values }) {

        # Get the Nodes defining the partners of the Interaction
        my @nodes;

        # TODO DES Necessary hack:
        # crashes when _nodes not yet defined in Bio::Network
        if (exists $i->{_nodes}) {
            @nodes = $i->nodes;
        }
        else {
            foreach my $key (@{ $i->keys }) {
                push(@nodes,
                    SBG::Node->new(SBG::Seq->new(-display_id => $key)));
            }
        }

        $net->add_interaction(-nodes => [@nodes], -interaction => $i);
    }

    return $net;
}    # network

=head2 stringify

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut

sub stringify {
    my ($self) = @_;
    $self->interactions->keys->sort->join(',');
}

=head2 transform

 Title   : transform
 Usage   :
 Function: Transforms each component L<SBG::Model> by a given L<PDL> matrix
 Example :
 Returns : 
 Args    : L<PDL> 4x4 homogenous transformation matrix


=cut

sub transform {
    my ($self, $matrix) = @_;

    # Note that interactions also contain models, but these are different copies
    # This should be optimized so that they are not duplicated.
    # In that case, do not transform both of these here, rather just the interaction
    $self->models->values->map(sub       { $_->transform($matrix) });
    $self->interactions->values->map(sub { $_->transform($matrix) });

    return $self;
}    # transform

=head2 coverage

 Function: How well do our domains cover those of B<$other>
 Example : 
 Returns : 
 Args    : 


In an array context, this returns the names of the common components

=cut

sub coverage {
    my ($self, $other) = @_;
    return unless defined $other;
    return intersection($self->keys, $other->keys);

}    # coverage

=head2 globularity

 Function: 
 Example : 
 Returns : [0,100]
 Args    : 

Estimates the extent of globularity of a complex as a whole as the ratio of the
rradius of gyration to the maximum radius, over all of the coordinates in the
complex (which may be all atoms, just residues, just centres-of-mass, etc)

This provides some measure of how compact, non-linear, the components in a
complex are arranged. E.g. high for an exosome, low for actin fibers

=cut

has 'globularity' => (
    is         => 'rw',
    lazy_build => 1,
    clearer    => 'clear_globularity',
);

sub _build_globularity {
    my ($self,) = @_;

    # Multidimensional piddle
    my $mcoords = $self->modelled_coords or return;
    my $coords = pdl $mcoords->values;

    # Flatten into 2D
    $coords = $coords->clump(1, 2) if $coords->dims == 3;
    return 100.0 * SBG::U::RMSD::globularity($coords);

}    # globularity

=head2 buried_area

Surface area buried at interfaces.

Depends on NACCESS program.

=cut

has 'buried_area' => (
    is         => 'rw',
    isa        => 'Maybe[Num]',
    lazy_build => 1,
    clearer    => 'clear_buried_area',
);

sub _build_buried_area {
    my ($self) = @_;
    my $sas = SBG::Run::naccess::buried($self->domains) or return;
    return $sas;
}

=head2 combine

 Function: Combines all of the domains in this complex into a single domain
 Example : 
 Returns : 
 Args    : 

TODO put in a DomainSetI

=cut

use SBG::DomainIO::pdb;
use Module::Load;

sub combine {
    my ($self, %ops) = @_;
    $ops{keys} ||= $self->keys;
    $log->debug($ops{keys}->join(','));
    my $doms = $self->domains($ops{keys});
    return unless $doms->length > 0;

    my $io =
        $ops{file}
        ? new SBG::DomainIO::pdb(file     => ">$ops{file}")
        : new SBG::DomainIO::pdb(tempfile => 1);
    $io->write(@$doms);
    my $type = ref $doms->[0];
    load($type);
    my $dom = $type->new(file => $io->file, descriptor => 'ALL');
    return $dom;
}    # combine

=head2 merge_domain

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut

sub merge_domain {
    my ($self, $other, $ref, $olap) = @_;
    $olap ||= 0.5;

    # Where the last reference domain for this component was placed in space
    my $refmodel = $self->get($ref);
    my $refdom = $refmodel->subject if defined $refmodel;
    return unless $refdom;

    my $othermodel = $other->get($ref);
    my $otherdom = $othermodel->subject if defined $othermodel;
    return unless $otherdom;

    #     return unless _model_overlap($refmodel, $othermodel) > 0;

    my $linker_superposition =
        SBG::Superposition::Cache::superposition($otherdom, $refdom);
    return unless defined $linker_superposition;

    # Then apply that transformation to the other complex
    # Product of relative with absolute transformation.
    # Order of application of transformations matters
    $log->debug("Linking:", $linker_superposition->transformation);

    # Transform the other complex
    $linker_superposition->apply($other);

    # Now test steric clashes of potential domain against existing domains
    my $clashfrac = $self->check_clashes($other->domains, $ref, $olap);
    return unless $clashfrac < 1;

    # Domain does not clash after being oriented, can be saved in complex now.
    # Save all meta data that went into this placement.
    # I.e. this pulls all domains from $other into $self
    # NB this appears to replace the pivot domain (on which we merge), but
    # that should not matter. All $other domains have been xformed already
    $self->set($_, $other->get($_)) for $other->keys->flatten;

    # Pull all interactions
    $self->interactions->put($_, $other->interactions->at($_))
        for $other->interactions->keys->flatten;

    # TODO save clash values (check_clashes should return ArrayRef)

    # Cache superpositions by reference domain (linking domain)
    $self->superpositions->put($refdom, $linker_superposition);

    # STAMP superposition score of linking superposition
    return $linker_superposition->scores->at('Sc');

}    # merge_domain

# True if the sequences being modelled by two models overlap
# Indended to enforce that shared components are actually shared and not just
# modelling seperate domains of a single chain, for example
sub _model_overlap {
    my ($model1, $model2) = @_;

    my ($query1, $query2) = map { $_->query } ($model1, $model2);
    return
        unless UNIVERSAL::isa($query1, 'Bio::Search::Hit::HitI')
            && UNIVERSAL::isa($query2, 'Bio::Search::Hit::HitI');

    my ($start1, $end1, $start2, $end2) =
        map { $_->start, $_->end } ($query1, $query2);

    # How much of model1's sequence is covered by model2's sequence
    my $seqoverlap =
        SBG::U::List::interval_overlap($start1, $end1, $start2, $end2);
    $log->debug("start1:$start1:end1:$end1:start2:$start2:end2:$end2");
    $log->debug("seqoverlap:$seqoverlap");

    unless ($seqoverlap > 0) {
        $log->warn("Sequences modelled do not overlap: ($model1, $model2)");
    }
    return $seqoverlap;
}

=head2 merge_interaction

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut

sub merge_interaction {
    my ($self, $other, $iaction, $olap) = @_;
    $olap ||= 0.5;

    # If this interaction is just to create a cycle in this complex
    # Difference of iRMSD from 10 is cheap way to get score in [0:10], as STAMP
    return 10 - $self->cycle($iaction)
        if refaddr($self) == refaddr($other);

    # Add Interaction to self
    my ($src, $dest) = $iaction->keys->flatten;

    # Figure out which end of interaction can be linked to $self complex
    unless ($self->models->exists($src)) {
        swap($src, $dest);
    }
    unless ($self->models->exists($src)) {
        $log->error("Neither $src nor $dest present in complex: $self");
        return;
    }
    my $iaction_score = $self->add_interaction($iaction, $src, $dest, $olap);
    return unless defined $iaction_score;

    # $dest node was added to $src complex, can now merge on $dest
    return $self->merge_domain($other, $dest, $olap);

}    # merge_interaction

=head2 cycle

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut

sub cycle {
    my ($self, $iaction) = @_;
    $log->debug($iaction);

    my $keys = $iaction->keys;

    # Get domains from self and domains from iaction in corresponding order
    my $irmsd =
        SBG::U::iRMSD::irmsd($self->domains($keys), $iaction->domains($keys));

    # TODO this thresh is also hard-coded in CA::Assembler2
    $self->ncycles($self->ncycles + 1) if $irmsd < 15;

    return $irmsd;

}    # cycle

=head2 init

 Function: 
 Example : 
 Returns : 
 Args    : 

Initialize a complex with a single interaction, i.e. a dimeric complex

TODO deprecate

=cut

sub init {
    my ($self, $iaction) = @_;

    my $keys = $iaction->keys;
    my $models = $keys->map(sub { $self->_mkmodel($iaction, $_) });
    $self->add_model(@$models);

    # Save a copy
    $self->interactions->put($iaction, $iaction->clone);

}    # init

=head2 add_interaction

 Function: 
 Example : 
 Returns : Success, whether interaction can be added
 Args    : L<SBG::Interaction>


NB Adding in interaction is a special case of merging complexes. The interaction
is a dimeric complex, which is internally consisten by definition (no steric
clashes, since we trust the interaction template). That dimeric complex is
linked to this complex via the reference domain.

TODO initialize a complex from an interaction object.

=cut

sub add_interaction {
    my ($self, $iaction, $srckey, $destkey, $olap) = @_;
    $olap ||= 0.5;

    # Where the last reference domain for this component was placed in space
    my $refmodel = $self->get($srckey);

    # NB here we use 'subject', not 'structure' to take advantage of
    # interactions coming from a single source structure
    # I.e. there may be identity transformations that we want to exploit
    my $refdom = $refmodel->subject if defined $refmodel;

    # Initial interaction, no spacial constraints yet, always accepted
    unless (defined $refdom) {
        $self->init($iaction);

        # TODO Poor approach to get the maximum score
        return 10.0;
    }

    # Get domain models for components of interaction
    my $srcmodel = $iaction->get($srckey);
    my $srcdom   = $srcmodel->subject;

    # For domain being placed, make a copy that has a concrete representation
    my $destmodel = $self->_mkmodel($iaction, $destkey);
    return unless defined $destmodel;
    my $destdom = $destmodel->subject;

    # Just verify model_overlap but don't enforce it
    _model_overlap($srcmodel, $refmodel);

    #     return unless _model_overlap($srcmodel, $refmodel) > 0;

    my $linker_superposition =
        SBG::Superposition::Cache::superposition($srcdom, $refdom);
    return unless defined $linker_superposition;

    # Then apply that transformation to the interaction partner $destdom.
    # Product of relative with absolute transformation.
    # Order of application of transformations matters
    $linker_superposition->apply($destmodel);
    $log->debug("Linking:", $linker_superposition->transformation);

    # Now test steric clashes of potential domain against existing domains
    my $clashfrac =
        $self->check_clashes([ $destmodel->structure ], undef, $olap);
    return unless $clashfrac < 1;

    # Domain does not clash after being oriented, can be saved in complex now.
    # Save all meta data that went into this placement.
    # NB Any previous $self->get($destnode) gets overwritten.
    # This is compatible with the backtracking of SBG::Traversal.
    $self->set($destkey, $destmodel);

    # TODO belongs in the 'scores' of the dest model
    $self->clashes->put($destkey, $clashfrac);

    # Cache by destnode, as there may be many for any given refdom
    $self->superpositions->put($destkey, $linker_superposition);

    # Copy and transform the interaction, to save it
    my $iaction_clone = $iaction->clone;
    $linker_superposition->apply($iaction_clone);
    $self->interactions->put($iaction_clone, $iaction_clone);
    return $linker_superposition->scores->at('Sc');

}    # add_interaction

# Create a concrete model for a given abstract model in an interaction
# TODO belongs in SBG::Model::clone()
use SBG::Run::cofm qw/cofm/;

sub _mkmodel {
    my ($self, $iaction, $key) = @_;
    my $vmodel = $iaction->get($key);
    my $vdom   = $vmodel->subject;

    # Clone first, to sever reference to original object
    my $clone = $vdom->clone;

    # Now copy construct into the desired type
    my $type = $self->objtype;

    # NB it is not sufficient to just do $type->new(%$clone) because cofm is
    # required to setup the radius.
    my $cdom =
        blessed($clone) eq 'SBG::Domain::Sphere' ? $clone : cofm($clone);
    return unless defined $cdom;

    # TODO DES need to be copy constructing
    my $model = SBG::Model->new(
        query   => $vmodel->query,
        subject => $cdom,
        scores  => $vmodel->scores,
        input   => $vmodel->input,
        aln     => $vmodel->aln,
    );

    # Needs to be cloned as well, as it will be transformed
    if (refaddr($vmodel->subject) != refaddr($vmodel->structure)) {
        my $struct_clone = $vmodel->structure->clone;
        $model->structure($struct_clone);
    }

    return $model;
}    # _mkmodel

=head2 check_clash

 Function:
 Example :
 Returns : 
 Args    :

Determine whether a given L<SBG::Domain> would create a clash/overlap in space
with any of the L<SBG::Domain>s in this complex.

TODO Deprecated in favor of L<check_clashes>

=cut

sub check_clash {
    my ($self, $newdom, $thresh) = @_;
    $thresh ||= 0.5;

    $log->debug("fractional overlap thresh:$thresh");
    my $overlaps = [];

    $log->debug("$newdom vs " . $self->models->values->join(','));

    # Get all of the objects in this assembly.
    # If any of them clashes with the to-be-added objects, then disallow
    foreach my $key (@{ $self->keys }) {

        # Measure the overlap between $newdom and each component
        my $existingdom = $self->get($key)->structure;
        $log->debug("$newdom vs $existingdom");
        my $overlapfrac = $newdom->overlap($existingdom);

        # Nonetheless, if one clashes severely, bail out
        return 1 if $overlapfrac > $thresh;

        # Ignore domains that aren't overlapping at all (ie < 0)
        $overlaps->push($overlapfrac) if $overlapfrac > 0;
    }
    my $mean = mean($overlaps) || 0;
    $log->debug("$newdom fits w/ mean overlap fraction: ", $mean);
    return $mean;
}    # check_clash

=head2 check_clashes

 Function: 
 Example : 
 Returns : 
 Args    : 

Clashes between two complexes.

TODO there are algorithms better than O(NxM) for this

$ignore is the pivot used to merge the complex, which doesn't need to be checked

=cut

sub check_clashes {
    my ($self, $otherdoms, $ignore, $olap) = @_;
    $olap ||= 0.5;
    $log->debug("fractional overlap thresh:$olap");
    my $overlaps = [];

    $log->debug($self->size, " vs ", $otherdoms->length);

    # Get all of the objects in this assembly.
    # If any of them clashes with the to-be-added objects, then disallow
    foreach my $key ($self->keys->flatten) {
        next if $ignore && $key eq $ignore;

        # Measure the overlap between $thisdom and each $otherdom
        my $thisdom = $self->get($key)->structure;
        foreach my $otherdom ($otherdoms->flatten) {
            $log->debug("$thisdom vs $otherdom");
            my $overlapfrac = $thisdom->overlap($otherdom);

            # Nonetheless, if one clashes severely, bail out
            return 1 if $overlapfrac > $olap;

            # Ignore domains that aren't overlapping at all (ie < 0)
            $overlaps->push($overlapfrac) if $overlapfrac > 0;
        }
    }
    my $mean = mean($overlaps) || 0;
    $log->debug("mean overlap fraction: ", $mean);
    return $mean;

}    # check_clashes

=head2 overlap

 Function: Measures spatial coverage between a model and a benchmark complex
 Example : 
 Returns : 
 Args    : 

TODO should be in a DomSetI interface


=cut

sub overlap {
    my ($self, $other) = @_;

    # Only consider common components
    my @cnames = $self->coverage($other);

    my $overlaps = [];
    foreach my $key (@cnames) {
        my $selfdom  = $self->get($key)->structure;
        my $otherdom = $other->get($key)->structure;

        # Returns negative distance if no overlap at all
        my $overlapfrac = $selfdom->overlap($otherdom);

        # Non-overlapping domains just become 0
        $overlapfrac = 0 if $overlapfrac < 0;
        $overlaps->push($overlapfrac);
    }
    my $mean = mean($overlaps) || 0;
    return $mean;

}    # overlap

=head2 rmsd

 Function:
 Example :
 Returns : 
 Args    :

RMSD between common domains between this and another complex.

Models are associated by name. Models present in one complex but not the other
are not considered. Undefined when no common component models.


TODO belongs in a ModelSet role

Based on putting centres of mass in right frame of reference

=cut

sub rmsd {
    my ($self, $other) = @_;

    # Only consider common components
    my @cnames = $self->coverage($other);
    unless (@cnames) {
        $log->error("No common components between complexes");
        return;
    }
    $log->debug(scalar(@cnames), " common components: @cnames");

    my $selfcofms  = [];
    my $othercofms = [];

    foreach my $key (@cnames) {
        my $selfdom  = $self->get($key)->structure;
        my $otherdom = $other->get($key)->structure;
        my $sup;
        $otherdom = cofm($otherdom);
        ($selfdom, $sup) = _setcrosshairs($selfdom, $otherdom) or next;
        $othercofms->push($otherdom);
        $selfcofms->push($selfdom);
    }

    unless ($selfcofms->length > 1) {
        $log->warn(
            "Too few component-wise superpositions to superpose complex");
        return;
    }

    my $selfcoords  = pdl($selfcofms->map(sub  { $_->coords }));
    my $othercoords = pdl($othercofms->map(sub { $_->coords }));
    $selfcoords = $selfcoords->clump(1, 2) if $selfcoords->dims == 3;
    $othercoords = $othercoords->clump(1, 2) if $othercoords->dims == 3;

    my $trans = SBG::U::RMSD::superpose($selfcoords, $othercoords);
    $log->debug($trans);

    # Now it has been transformed already. Can measure RMSD of new coords
    my $rmsd = SBG::U::RMSD::rmsd($selfcoords, $othercoords);
    $log->info("rmsd:", $rmsd);
    return wantarray ? ($trans, $rmsd) : $rmsd;

}    # rmsd

=head2 rmsd_class

 Function: 
 Example : 
 Returns : 
 Args    : 

Determine bijection by testing all combinations in homologous classes

If one complex is modelling the other, call this as $model->rmsd($benchmark)

=cut

sub rmsd_class {
    my ($self, $other) = @_;

    # Upper sentinel for RMSD
    my $maxnum   = inf();
    my $bestrmsd = $maxnum;
    my $besttrans;
    my $bestmapping;
    my $bestnatoms;
    my $besti = -1;

    # TODO DES all of this set intersection business needs to be factored out
    # E.g. @set_of_classes = $complex->intersect($other_complex);

    # The complex model knows the symmetry of the components being built, even
    # the ones that were not explicitly modelled in this complex.
    # Group components into homologous classes (a component is in just one class)
    my @cc = $self->symmetry->flatten;

    # The components actually being modelled in this complex, sorted by class,
    # since we about to generate permutations of each class. The order of the
    # classes in @cc must be the same as the order of classes in $model I.e. if
    # class [B E] is first in @cc, then any B or E present must also be first in
    # $model
    my $keys = $self->keys;

    # Model componentspresent, grouped by class
    my $model = [ map { scalar _members_by_class($_, $keys) } @cc ];

    # Flat list
    my @model = flatten $model;

    # Counts per class
    my $kclass = $model->map(sub { $_->length });

    # Permute all members within each class, based on members present in model
    # Cartesian product of permutations
    my $pm =
        SBG::U::CartesianPermutation->new(classes => \@cc, kclass => $kclass);

    my $icart  = 0;
    my $ncarts = $pm->cardinality;

    # Measure the rate of improvement of the RMSD, give up when it flattens
    my $rate_rmsd;
    my $ref_rmsd;

    while (my $cart = $pm->next) {
        $icart++;
        my @cart = flatten $cart;

        # Map each component present to a possible component in the benchmark
        my %mapping = mesh(@model, @cart);

        # TODO verify that current connection topology is subgraph of target
        # This is quicker than subgraph isomorphism because the classes of the
        # nodes are known. This is just a filter, to skip non-equiv topologies.
        # Nodes don't have to be the same node, just of the same node class
        # Shortcut: for each edge in model, is it in the target?
        # Use the current mapping. If not, can skip RMSD calculation

        # Test this mapping
        my ($trans, $rmsd, $natoms) =

            #            rmsd_mapping($self, $other, \@model, \%mapping);
            rmsd_mapping_backbone($self, $other, \@model, \%mapping);

        if (!defined $rmsd) {
            $log->debug("RMSD \#$icart undef");
            next;
        }

        $log->debug("rmsd \#$icart / $ncarts: $rmsd");
        $log->debug("bestrmsd \#$besti: ", $bestrmsd || 'undef');
        $log->debug("is rmsd < bestrmsd: ",
            defined($rmsd) && defined($bestrmsd) && $rmsd < $bestrmsd);

        # TODO could also do a weighting here:
        # (slightly worse RMSD over many more atoms could be better choice)
        if (!defined($bestrmsd) || $rmsd < $bestrmsd) {
            $bestrmsd    = $rmsd;
            $besttrans   = $trans;
            $bestnatoms  = $natoms;
            $bestmapping = \%mapping;
            $besti       = $icart;
            $log->debug(
                "better rmsd \#$icart: $rmsd ($natoms CAs) via: @cart");
        }

        # Quit if we're not improving
        # Start with the first RMSD as a refernce
        $ref_rmsd ||= $bestrmsd;
        my $nsteps = 1000;
        my $thresh = 0.01;    # 1%
        if (0 == $icart % $nsteps) {
            my $improved = $ref_rmsd - $bestrmsd;
            my $rate     = $improved / $ref_rmsd;

            # Reset for next round
            $ref_rmsd = $bestrmsd;
            if ($rate < $thresh) {

                # Improved less than $thresh in $nsteps;
                $log->info("Rate $rate ($improved in $nsteps) < $thresh");
                last;
            }
        }
    }
    $log->info("Final RMSD: $bestrmsd");
    return wantarray
        ? ($besttrans, $bestrmsd, $bestmapping, $bestnatoms)
        : $bestrmsd;

}    # rmsd_class

#
sub _members_by_class {
    my ($class, $members) = @_;

    # Stringify (in case of objects)
    $class = [ map {"$_"} @$class ];
    my @present = grep {
        my $c = $_;
        grep { $_ eq $c } @$members
    } @$class;
    return wantarray ? @present : \@present;
}

=head2 rmsd_mapping

 Function: Do RMSD-CofM of domains with the given label mapping
 Example : 
 Returns : 
 Args    : 

Based on using the 7-point crosshairs, after setting correct frame of ref, which
is done by STAMP superposition.

=cut

sub rmsd_mapping {
    my ($self, $other, $keys, $mapping) = @_;

    my $selfcofms  = [];
    my $othercofms = [];
    foreach my $selflabel (@$keys) {
        my $selfdom = $self->get($selflabel)->structure;

        my $otherlabel = $mapping->{$selflabel} || $selflabel;
        my $otherdom = $other->get($otherlabel)->structure;
        $otherdom = cofm($otherdom);

        my $sup;
        ($selfdom, $sup) = _setcrosshairs($selfdom, $otherdom) or next;

        $othercofms->push($otherdom);
        $selfcofms->push($selfdom);
    }

    unless ($selfcofms->length > 1) {
        $log->warn(
            "Too few component-wise superpositions to superpose complex");
        return;
    }

    my $selfcoords  = pdl($selfcofms->map(sub  { $_->coords }));
    my $othercoords = pdl($othercofms->map(sub { $_->coords }));
    $selfcoords = $selfcoords->clump(1, 2) if $selfcoords->dims == 3;
    $othercoords = $othercoords->clump(1, 2) if $othercoords->dims == 3;

    # Least squares fit of all coords in each complex
    my $trans = SBG::U::RMSD::superpose($selfcoords, $othercoords);

    # Now it has been transformed already. Can measure RMSD of new coords
    my $rmsd = SBG::U::RMSD::rmsd($selfcoords, $othercoords);

    # The RMSD achieved if we assume this domain-domain mapping
    $log->debug("Potential rmsd:", $rmsd, " via: ", join ' ', %$mapping);
    return wantarray ? ($trans, $rmsd) : $rmsd;

}    # rmsd_mapping

=head2 rmsd_mapping_backbone

 Function: Do RMSD of domains with the given label mapping.
 Example : 
 Returns : 
 Args    : 

Uses the aligned residue correspondance to determine the RMSD over the aligned
backbone. The residue correspondance is extracted from the sequence
alignment. The sequence coords are then mapped, via DB::res_mapping to residue
IDs, whose coordinates are extracted from the native structures, then any
transformation is applied to set the frame of reference. This is done for every
possible domain-domain correspondance that might have results from homologous
components. The RMSD is then computed after doing a least squares fit of the
aligned CA backbone atoms.

This probably requires that $self be the model, while $other is the benchmark

TODO don't duplicate what's already in _build_modelled_coords

TODO would be smarter to have all the coordinates for $other preloaded and just
subset them rather than fetch them anew each time, which we do because it's a
different subset of the coordinates, depening on which modelled domain the given
benchmark domain is being compared to.

=cut

sub rmsd_mapping_backbone {
    my ($self, $other, $keys, $mapping) = @_;

    # Cache atomic coordinates, as they will be repeated many times
    our $native_coords;
    our $modelled_coords;
    $native_coords   ||= {};
    $modelled_coords ||= {};

    my $selfdomcoords  = [];
    my $otherdomcoords = [];

    # unique object key
    my $refaddr = refaddr $self;

    foreach my $selflabel (@$keys) {
        my $otherlabel = $mapping->{$selflabel} || $selflabel;
        my $cachekey = join '--', $refaddr, $selflabel, $otherlabel;
        my $mcoords  = $modelled_coords->{$cachekey};
        my $ncoords  = $native_coords->{$cachekey};

        if (defined $mcoords && defined $ncoords) {
            $selfdomcoords->push($mcoords);
            $otherdomcoords->push($ncoords);
            next;
        }

        my $aln = $self->get($selflabel)->aln();

        if ($selflabel ne $otherlabel) {

            # Here we're trying an alternative mapping of query sequences to
            # templates, but the alternative sequence must be aligned to the
            # template used for modelling, before extracting atomic coordinates.
            $aln = _realign($aln, $selflabel, $otherlabel);
        }

        ($mcoords, $ncoords) =
            $self->_coords_from_aln($aln, $selflabel, $mapping)
            or return;

        $modelled_coords->{$cachekey} = $mcoords;
        $native_coords->{$cachekey}   = $ncoords;

        $selfdomcoords->push($mcoords);
        $otherdomcoords->push($ncoords);

    }

    # Now combine them into one coordinate set for the whole complex
    my $selfcoords  = pdl($selfdomcoords);
    my $othercoords = pdl($otherdomcoords);

    # Make 2-dimensional, if 3-dimensional
    $selfcoords = $selfcoords->clump(1, 2) if $selfcoords->dims == 3;
    $othercoords = $othercoords->clump(1, 2) if $othercoords->dims == 3;

    my $natoms = $selfcoords->getdim(1);
    $log->debug("RMSD over $natoms C-alpha atoms");

    # Least squares fit of all coords in each complex
    # Maximum 1000 refinement steps (unless it converges sooner)
    my $trans = SBG::U::RMSD::superpose($selfcoords, $othercoords, 1000);

    # Now it has been transformed already. Can measure RMSD of new coords
    my $rmsd = SBG::U::RMSD::rmsd($selfcoords, $othercoords);
    $log->debug("Potential rmsd:", $rmsd, " via: ", join ' ', %$mapping);
    return wantarray ? ($trans, $rmsd, $natoms) : $rmsd;

}    # rmsd_mapping_backbone {

=head2 _realign

 Function: 
 Example : 
 Returns : 
 Args    : 


Just add the mapped sequence (from pdbseq) to the alignment, using the blast alignment as a seed/profile alignment, then re-align (clustal), the remove the original benchmark/query sequence from the alignment.

e.g. if B=>D
Then D is added to the alignment, re-aligned, then B is removed. And the coords returned are those for D


=cut

sub _realign {
    my ($aln, $selflabel, $otherlabel) = @_;

    # Determine PDB ID and chain ID to add to alignment
    my ($pdbid, $chainid) = $otherlabel =~ /$pdb41/;

    # Fetch the new sequence
    my $dom =
        SBG::Domain->new(pdbid => $pdbid, descriptor => "CHAIN $chainid");
    my $seq = pdbseq($dom);

    # Reset the display ID
    $seq->display_id($pdbid . $chainid);

    # Add to alignment, clone it first (not done by factory already?)
    my $clustal = Bio::Tools::Run::Alignment::Clustalw->new(quiet => 1);
    $aln = clone($aln);
    $aln = $clustal->profile_align($aln, $seq);

    # Remove $selflabel from alignment
    $aln->remove_seq($aln->get_seq_by_id($selflabel));

    return $aln;

}    # _realign

=head2 _coords_from_aln

 Function: 
 Example : [ $modelled, $benchmark ] = _coords_from_aln($aln, $query_label)
 Returns : [ modelled_coords, query/benchmark_coords ]
 Args    : 


Extract X,Y,Z atomic coordinates for residues of aligned PDB structures

The query is the sequence to be modelled. When benchmarking, this is the native
structure, which is determined by extracting the PDB ID / chain ID from the
label, e.g. 1timA.


=cut

sub _coords_from_aln {
    my ($self, $aln, $querykey, $mapping) = @_;
    $mapping ||= {};

    # Map pdbseq sequence coordinates to PDB residue IDs
    my $seqcoords = { SBG::DB::res_mapping::aln2locations($aln) };
    my $mappedkey = $mapping->{$querykey} || $querykey;

    # Get the name of the one that's not the querykey
    my ($subjectkey) =
        $seqcoords->keys->grep(sub { $_ ne $mappedkey })->flatten;

    # Convert pdb|1tim|AA to '1tima', returns a [ pdb, chain ] tuple
    my ($pdb_chain) = gi2pdbid($subjectkey);
    my $subjectkeyshort = join '', @$pdb_chain;

    my $labels = {
        $querykey        => $mappedkey,
        $subjectkeyshort => $subjectkey,
    };
    my $coords = {};

    # If we fail to extract all coordinates, arbitarily chop off some
    # This is not correct, but will provide an approximation, still useful
    my $ichop;
    foreach my $key ($labels->keys->flatten) {
        my $alnlabel = $labels->{$key};

        # Replace key for the benchmark with its mapping, if any
        $key = $mapping->{$key} || $key;
        my ($pdbid, $chainid) = $key =~ /$pdb41/;

        my $seqcoords = $seqcoords->{$alnlabel};
        my $resids =
            SBG::DB::res_mapping::query($pdbid, $chainid, $seqcoords);
        $resids or return;
        my $nfound = scalar @$resids;
        $ichop ||= $nfound;
        unless ($nfound == scalar(@$seqcoords)) {
            $log->error(
                "Could not extract all residue coordinates from $subjectkey");
            $ichop = min($ichop, $nfound, scalar @$seqcoords);
            $resids = $resids->slice([ 0 .. $ichop - 1 ]);
        }

        # Note we start with the whole chain here but we're only extracting the
        # aligned residues. This will be the atomic representation. And since we
        # never use the Domain object itself, the fact that the descriptor
        # refers to the whole chain is not relevant.
        # TODO BUG fails when no pdbid, need to be able to bench anon structures
        my $dom = SBG::Domain::Atoms->new(
            pdbid      => $pdbid,
            descriptor => "CHAIN $chainid",
            residues   => $resids
        );

        # If this is the modelled domain, set it's frame of reference
        if ($key eq $subjectkeyshort) {
            my $trans = $self->get($querykey)->transformation;
            $trans->apply($dom);
        }
        $coords->{$key} = $dom->coords;
    }

    # Force them to be the same dimensions by blatantly chopping the longer
    # This loses the 1-to-1 correspondance, but still aligns well if off by 1

    my $mapped_coords  = $coords->{$mappedkey};
    my $subject_coords = $coords->{$subjectkeyshort};

    # Truncate both, simply from the end
    # May be off by a few residues, but better than giving up
    my $nchop =
        min($ichop, $mapped_coords->dim(1), $subject_coords->dim(1)) - 1;
    $coords->{$subjectkeyshort} = $subject_coords->slice(":,0:$nchop");
    $coords->{$mappedkey}       = $mapped_coords->slice(":,0:$nchop");

    # The subject is what was modelled, the query is the benchmark
    return $coords->{$subjectkeyshort}, $coords->{$mappedkey}

}    # _coords_from_aln

# set crosshairs of one domain, based on second
sub _setcrosshairs {
    my ($selfdom, $otherdom) = @_;

    # Now get the superposition from current $selfdom onto current $otherdom
    my $sup = SBG::Superposition::Cache::superposition($selfdom, $otherdom);
    return unless $sup;

    # Set crosshairs
    $selfdom = cofm($selfdom);

    # Transform
    $sup->apply($selfdom);

    # Rebuild crosshairs over there
    $selfdom->_build_coords;

    # Reverse transform. After this, superpositioning $selfdom onto $otherdom
    # should align crosshairs
    $sup->inverse->apply($selfdom);

    return wantarray ? ($selfdom, $sup) : $selfdom;
}    # _setcrosshairs

# TODO DES belongs in a Role, as there may be many approaches to finding these
# And this one is way too slow
sub contacts {
    my ($self) = @_;
    return [];

    #    my $contacts = qcons($self->domains);
    #    return $contacts;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;

