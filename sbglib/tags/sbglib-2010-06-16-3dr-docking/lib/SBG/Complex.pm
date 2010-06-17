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

with 'SBG::DomainSetI';
with 'SBG::Role::Clonable';
with 'SBG::Role::Scorable';
with 'SBG::Role::Storable';
with 'SBG::Role::Transformable';
with 'SBG::Role::Versionable';
with 'SBG::Role::Writable';

use overload (
    '""' => 'stringify',
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
use Log::Any qw/$log/;
use bignum; # qw/inf/;

use Algorithm::Combinatorics qw/variations/;
use Bio::Tools::Run::Alignment::Clustalw;


use SBG::Types qw/$pdb41/;
use SBG::U::List 
    qw/interval_overlap intersection mean min sum flatten swap cartesian_product/;
use SBG::U::RMSD;
use SBG::U::iRMSD; # qw/irmsd/;
use SBG::STAMP; # qw/superposition/
use SBG::Superposition::Cache; # qw/superposition/;
use SBG::DB::res_mapping; # qw/query aln2locations/;
use SBG::U::DB qw/chain_case/;
use SBG::Run::PairedBlast qw/gi2pdbid/;
use SBG::Run::pdbseq qw/pdbseq/;

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




=head2 id

 Function: 
 Example : 
 Returns : 
 Args    : 

Convenience label

=cut
has 'id' => (
    is => 'rw',
    isa => 'Str',
    );


# Cluster, for duplicate complexes
has 'class' => (
    is => 'rw',
    isa => 'Str',
    );



=head2 name

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
has 'name' => (
    is => 'rw',
    isa => 'Str',
    );



=head2 description

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
has 'description' => (
    is => 'rw',
    isa => 'Str',
    );




=head2 objtype

 Function: Type of L<SBG::DomainI> object to use for clash detection
 Example : 
 Returns : 
 Args    : 
 Default : 'SBG::Domain::Sphere'

=cut
has 'objtype' => (
    is => 'ro',
    isa => 'ClassName',
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
    isa => 'HashRef[SBG::Interaction]',
    is => 'ro',
    lazy => 1,
    default => sub { { } },
    );



sub pdbids {
    my ($self) = @_;
    my $iactions = $self->interactions->values;
    my $pdbids = $iactions->map(sub{$_->pdbid});
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
    isa => 'HashRef[SBG::Superposition]',
    is => 'ro',
    lazy => 1,
    default => sub { { } },
    );




=head2 ncycles

 Function: Number of ring closures modelled by known interaction templates
 Example : 
 Returns : 
 Args    : 



=cut
has 'ncycles' => (
    is => 'rw',
    default => sub { 0 },
    );


=head2 clashes

Fractional overlap/clash of each domain when it was added to the complex. This
is not updated when subsequent domains are added. This has the nice side-effect
that overlaps are not double-counted. Each domain stores the clashes it
encounted at the time it was added.

E.g attach(A), attach(B), attach(C). If A and C clash, A wont know about it,
but C will have saved it, having been added subsequently.

Indexed by the L<SBG::Node> creating the clashes when it was added.

=cut
has 'clashes' => (
    isa => 'HashRef[Num]',
    is => 'ro',
    lazy => 1,
    default => sub { { } },
    );
# TODO each clash should be saved in the 'scores' hash of the Superposition



=head2 models

 Function: Maps accession number of protein components to L<SBG::Model> model.
 Example : $cmplx->set('RRP43',
               new SBG::Model(query=>$myseq, subject=>$template_domain))
 Returns : The one L<SBG::Domain> modelling the protein, if any
 Args    : display_id

Indexed by display_id of L<SBG::Node> modelled by this L<SBG::Model>

=cut
has 'models' => (
    isa => 'HashRef[SBG::Model]',
    is => 'ro',
    lazy => 1,
    default => sub { {} },
    );




=head2 symmetry

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
has 'symmetry' => (
    is => 'rw',
    isa => 'Graph',
    );



=head2 score

 Function: 
 Example : 
 Returns : 
 Args    : 


Combined score of all domain models in a complex

=cut
has 'score' => (
    is => 'rw',
    lazy_build => 1,
    );

sub _build_score {
    my ($self) = @_;

    return 1;
}


###############################################################################
=head2 domains

 Function: Extracts just the Domain objects from the Models in the Complex
 Example : 
 Returns : ArrayRef[SBG::DomainI]
 Args    : 


=cut
sub domains {
    my ($self, $keys, $map) = @_;

    # Order of models attribute
    $keys ||= $self->keys;
    return unless @$keys;

    if (defined $map) {
        $keys = $keys->map(sub{$map->{$_} || $_});
    }
    my $models = $keys->map(sub{ $self->get($_) });
    my $domains = $models->map(sub { $_->subject });
    return $domains;

} # domains



=head2 count

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub count {
    my ($self,) = @_;
    return $self->models->keys->length;

} # count



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

} # size



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
} # set
sub get {
    my $self = shift;
    return $self->models->at(@_);
}
sub keys {
    my $self = shift;
    return $self->models->keys->sort;
}


# Mapping to names used to correspond to another structure
has 'correspondance' => (
    is => 'rw',
    isa => 'HashRef[Str]',
    default => sub { {} },
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
    is => 'rw',
    lazy_build => 1,
    );
sub _build_modelled_coords {
    my ($self) = @_;
    my $modelled_coords = {};    
    my $keys = $self->keys;

    foreach my $key (@$keys) {
        my $dommodel = $self->get($key);
        my $aln = $dommodel->aln();
        my ($modelled, $native) = 
            $self->_coords_from_aln($aln, $key) or return;
        $modelled_coords->{$key} = $modelled;
    }

    return $modelled_coords;
    
} # _build_modelled_coords


=head2 coords

 Function: 
 Example : 
 Returns : 
 Args    : 


TODO Belongs in DomSetI

=cut
sub coords {
    my ($self,@cnames) = @_;
    # Only consider common components
    @cnames = ($self->models->keys) unless @cnames;
    @cnames = flatten(@cnames);
    
    my @aslist = map { $self->get($_)->subject->coords } @cnames;
    my $coords = pdl(@aslist);
    
    # Clump into a 2D matrix, if there is a 3rd dimension
    # I.e. normally have an outer dimension representing individual domains.
    # Then each domain is a 2D matrix of coordinates
    # This clumps the whole set of domains into a single matrix of coords
    $coords = $coords->clump(1,2) if $coords->dims == 3;
    return $coords;
    
} # coords



=head2 add_model

 Function: 
 Example : 
 Returns : 
 Args    : L<SBG::Model>


=cut
sub add_model {
    my ($self, @models) = @_;
    $self->models->put($_->query, $_) for @models;
} # add_model



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
    is => 'rw',
    isa => 'SBG::Network',
    lazy_build => 1,
    );


sub _build_network {
    my ($self) = @_;

    my $net = SBG::Network->new;

    # Go through %{ $self->interactions }
    foreach my $i (@{$self->interactions->values}) {
        # Get the Nodes defining the partners of the Interaction
        my @nodes;
        # TODO DES Necessary hack: 
        # crashes when _nodes not yet defined in Bio::Network
        if (exists $i->{_nodes}) {
            @nodes = $i->nodes;
        } else {
            foreach my $key (@{$i->keys}) {
                push(@nodes,
                     SBG::Node->new(SBG::Seq->new(-display_id=>$_)));
            }
        }
        $net->add_node($_) for @nodes;
        $net->add_interaction(
            -nodes=>[@nodes],-interaction=>$i);
    }

    return $net;
} # network



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
   my ($self,$matrix) = @_;
   foreach my $model (@{$self->models->values}) {
       # The Model contains a 'query' (component) and a 'subject' (domain model)
       my $domain = $model->subject;
       $domain->transform($matrix);
   }
} # transform



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

} # coverage



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
    is => 'rw',
    lazy_build => 1,
    );

sub _build_globularity {
    my ($self,) = @_;

    # Multidimensional piddle
    my $mcoords = $self->modelled_coords or return;
    my $coords = pdl $mcoords->values;
    # Flatten into 2D
    $coords = $coords->clump(1,2) if $coords->dims == 3;
    return 100.0 * SBG::U::RMSD::globularity($coords);

} # globularity



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
    my ($self,%ops) = @_;
    $ops{keys} ||= $self->keys;
    my $doms = $self->domains($ops{keys});
    return unless $doms->length > 0;

    my $io = $ops{file} ?
        new SBG::DomainIO::pdb(file=>">$ops{file}") :
        new SBG::DomainIO::pdb(tempfile=>1);
    $io->write(@$doms);
    my $type = ref $doms->[0];
    load($type);
    my $dom = $type->new(file=>$io->file, descriptor=>'ALL');
    return $dom;
} # combine



=head2 merge_domain

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub merge_domain {
    my ($self,$other,$ref, $olap) = @_;
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
    $linker_superposition->apply($_) for $other->domains->flatten;

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

} # merge


# True if the sequences being modelled by two models overlap
# Indended to enforce that shared components are actually shared and not just 
# modelling seperate domains of a single chain, for example
sub _model_overlap {
    my ($model1, $model2) = @_;

    my ($query1, $query2) = map { $_->query } ($model1, $model2);
    return unless 
        UNIVERSAL::isa($query1, 'Bio::Search::Hit::HitI') &&
        UNIVERSAL::isa($query2, 'Bio::Search::Hit::HitI');

    my ($start1, $end1, $start2, $end2) = 
        map { $_->start, $_->end } ($query1, $query2);
    # How much of model1's sequence is covered by model2's sequence
    my $seqoverlap = SBG::U::List::interval_overlap(
        $start1, $end1, $start2, $end2);
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
    my $iaction_score = $self->add_interaction(
        $iaction, $src, $dest, $olap);
    return unless defined $iaction_score;

    # $dest node was added to $src complex, can now merge on $dest
    return $self->merge_domain($other, $dest, $olap);

} # merge_interaction



=head2 cycle

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub cycle {
    my ($self, $iaction) = @_;
    $log->info($iaction);

    my $keys = $iaction->keys;
    # Get domains from self and domains from iaction in corresponding order
    my $irmsd = SBG::U::iRMSD::irmsd($self->domains($keys), 
                                     $iaction->domains($keys));

    # TODO this thresh is also hard-coded in CA::Assembler2
    $self->ncycles($self->ncycles+1) if $irmsd < 15;

    return $irmsd;

} # cycle



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
    my $models = $keys->map(sub{$self->_mkmodel($iaction, $_)});
    $self->add_model(@$models);
    $self->interactions->put($iaction, $iaction);

} # init



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
    my $refdom = $refmodel->subject if defined $refmodel;
    # Initial interaction, no spacial constraints yet, always accepted
    unless (defined $refdom) {
        $self->init($iaction);
        # TODO Poor approach to get the maximum score
        return 10.0;
    }

    # Get domain models for components of interaction
    my $srcmodel = $iaction->get($srckey);
    my $srcdom = $srcmodel->subject;
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
    $linker_superposition->apply($destdom);
    $log->debug("Linking:", $linker_superposition->transformation);

    # Now test steric clashes of potential domain against existing domains
    my $clashfrac = $self->check_clashes([$destdom], undef, $olap);
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
    $self->interactions->put($iaction, $iaction);
    return $linker_superposition->scores->at('Sc');

} # add_interaction


# Create a concrete model for a given abstract model in an interaction
use SBG::Run::cofm qw/cofm/;
sub _mkmodel {
    my ($self, $iaction, $key) = @_;
    my $vmodel = $iaction->get($key);
    my $vdom = $vmodel->subject;

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
        query=>$vmodel->query, 
        subject=>$cdom, 
        scores=>$vmodel->scores,
        input=>$vmodel->input,
        aln=>$vmodel->aln,
        );

    return $model;
} # _mkmodel



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
    foreach my $key (@{$self->keys}) {
        # Measure the overlap between $newdom and each component
        my $existingdom = $self->get($key)->subject;
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
} # check_clash



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
    my ($self, $otherdoms, $ignore, $olap ) = @_;
    $olap ||= 0.5;
    $log->debug("fractional overlap thresh:$olap");
    my $overlaps = [];

    $log->debug($self->size, " vs ", $otherdoms->length);

    # Get all of the objects in this assembly. 
    # If any of them clashes with the to-be-added objects, then disallow
    foreach my $key ($self->keys->flatten) {
        next if $ignore && $key eq $ignore;
        # Measure the overlap between $thisdom and each $otherdom
        my $thisdom = $self->get($key)->subject;
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

} # check_clashes



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
        my $selfdom = $self->get($key)->subject;
        my $otherdom = $other->get($key)->subject;
        
        # Returns negative distance if no overlap at all
        my $overlapfrac = $selfdom->overlap($otherdom);
        # Non-overlapping domains just become 0
        $overlapfrac = 0 if $overlapfrac < 0;
        $overlaps->push($overlapfrac);
    }
    my $mean = mean($overlaps) || 0;
    return $mean;

} # overlap




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
   my ($self,$other) = @_;
   # Only consider common components
   my @cnames = $self->coverage($other);
   unless (@cnames) {
       $log->error("No common components between complexes");
       return;
   }
   $log->debug(scalar(@cnames), " common components: @cnames");

   my $selfcofms = [];
   my $othercofms = [];

   foreach my $key (@cnames) {
       my $selfdom = $self->get($key)->subject;
       my $otherdom = $other->get($key)->subject;
       my $sup;
       $otherdom = cofm($otherdom);
       ($selfdom, $sup) = _setcrosshairs($selfdom, $otherdom) or next;
       $othercofms->push($otherdom);
       $selfcofms->push($selfdom);
   }

   unless ($selfcofms->length > 1) {
       $log->warn("Too few component-wise superpositions to superpose complex");
       return;
   }

   my $selfcoords = pdl($selfcofms->map(sub{ $_->coords }));
   my $othercoords = pdl($othercofms->map(sub{ $_->coords }));
   $selfcoords = $selfcoords->clump(1,2) if $selfcoords->dims == 3;
   $othercoords = $othercoords->clump(1,2) if $othercoords->dims == 3;

   my $trans = SBG::U::RMSD::superpose($selfcoords, $othercoords);
   $log->debug($trans);
   # Now it has been transformed already. Can measure RMSD of new coords
   my $rmsd = SBG::U::RMSD::rmsd($selfcoords, $othercoords);
   $log->info("rmsd:", $rmsd);
   return wantarray ? ($trans, $rmsd) : $rmsd;

} # rmsd





=head2 rmsd_class

 Function: 
 Example : 
 Returns : 
 Args    : 

Determine bijection by testing all combinations in homologous classes

If one complex is modelling the other, call this as $model->rmsd($benchmark)

=cut
sub rmsd_class {
    my ($self,$other) = @_;
    
    # Upper sentinel for RMSD
    my $maxnum = inf();
    my $bestrmsd = $maxnum;
    my $besttrans;
    my $bestmapping;
    my $besti = -1;

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
    my $kclass = $model->map(sub{$_->length});

    # Permute all members within each class, based on members present in model
    # Cartesian product of permutations
    my $pm = SBG::U::CartesianPermutation->new(classes=>\@cc, kclass=>$kclass);

    my $icart = 0;
    my $ncarts = $pm->cardinality;

    while (my $cart = $pm->next) {
        $icart++;
        my @cart = flatten $cart;
        # Map each component present to a possible component in the benchmark
        my %mapping = mesh(@model, @cart);

        # Test this mapping
        my ($trans, $rmsd) = 
#             rmsd_mapping($self, $other, $model, \%mapping);
            rmsd_mapping_backbone($self, $other, \@model, \%mapping);

        $log->debug("rmsd \#$icart / $ncarts: ", $rmsd || 'undef');
        $log->debug("bestrmsd \#$besti: ", $bestrmsd||'undef');
        $log->debug("rmsd<bestrmsd: ", 
                    defined($rmsd) && defined($bestrmsd) && $rmsd<$bestrmsd);
        next unless defined $rmsd;
        if (! defined($bestrmsd) || $rmsd < $bestrmsd) {
            $bestrmsd = $rmsd;
            $besttrans = $trans;
            $bestmapping = \%mapping;
            $besti = $icart;
            $log->debug("better rmsd \#$icart: $rmsd via: @cart");
        }
        # Shortcut for bailing out early, if the answer is already good enough
        # I.e. accept 10A if 10,000 tries already, or accept < 1A if 1000 tries
        if (! ($icart % 1000)) {
            for my $i (1..20) {
                if ($bestrmsd < $i && $icart > $i * 10_000) {
                    $log->info("Good enough: $bestrmsd");
                    return wantarray ? 
                        ($besttrans, $bestrmsd, $bestmapping) : $bestrmsd;
                }
            }
        }
        last if $icart > 500_000;
    }
    
    return wantarray ? ($besttrans, $bestrmsd, $bestmapping) : $bestrmsd;
    
} # rmsd_class


#
sub _members_by_class {
    my ($class, $members) = @_;
    # Stringify (in case of objects)
    $class = [ map { "$_" } @$class ];
    my @present = grep { my $c=$_; grep { $_ eq $c  } @$members } @$class;
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
    
    my $selfcofms = [];
    my $othercofms = [];
    foreach my $selflabel (@$keys) {
        my $selfdom = $self->get($selflabel)->subject;
        
        my $otherlabel = $mapping->{$selflabel} || $selflabel;
        my $otherdom = $other->get($otherlabel)->subject;
        $otherdom = cofm($otherdom);
        
        my $sup;
        ($selfdom, $sup) = _setcrosshairs($selfdom, $otherdom) or next;
        
        $othercofms->push($otherdom);
        $selfcofms->push($selfdom);
    }
    
    unless ($selfcofms->length > 1) {
        $log->warn("Too few component-wise superpositions to superpose complex");
        return;
    }
    
    my $selfcoords = pdl($selfcofms->map(sub{ $_->coords }));
    my $othercoords = pdl($othercofms->map(sub{ $_->coords }));
    $selfcoords = $selfcoords->clump(1,2) if $selfcoords->dims == 3;
    $othercoords = $othercoords->clump(1,2) if $othercoords->dims == 3;
    
    # Least squares fit of all coords in each complex
    my $trans = SBG::U::RMSD::superpose($selfcoords, $othercoords);
    # Now it has been transformed already. Can measure RMSD of new coords
    my $rmsd = SBG::U::RMSD::rmsd($selfcoords, $othercoords);
    # The RMSD achieved if we assume this domain-domain mapping
    $log->debug("Potential rmsd:", $rmsd, " via: ", join ' ', %$mapping);
    return wantarray ? ($trans, $rmsd) : $rmsd;
    
} # rmsd_mapping


=head2 rmsd_mapping_backbone

 Function: Do RMSD of domains with the given label mapping.
 Example : 
 Returns : 
 Args    : 

Uses the aligned residue correspondance to determine the RMSD over the aligned
backbone. The residues correspondance is extracted from the sequence
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
    $native_coords ||= {};
    $modelled_coords ||= {};

    my $selfdomcoords = [];
    my $otherdomcoords = [];

    foreach my $selflabel (@$keys) {
        my $otherlabel = $mapping->{$selflabel} || $selflabel;
        my $cachekey = join '--', $self->id, $selflabel, $otherlabel;
        my $mcoords = $modelled_coords->{$cachekey};
        my $ncoords = $native_coords->{$cachekey};

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
            $self->_coords_from_aln($aln, $selflabel, $mapping) or return;

        $modelled_coords->{$cachekey} = $mcoords;
        $native_coords->{$cachekey} = $ncoords;

        $selfdomcoords->push($mcoords);
        $otherdomcoords->push($ncoords);

    }

    # Now combine them into one coordinate set for the whole complex
    my $selfcoords = pdl($selfdomcoords);
    my $othercoords = pdl($otherdomcoords);
    # Make 2-dimensional, if 3-dimensional
    $selfcoords = $selfcoords->clump(1,2) if $selfcoords->dims == 3;
    $othercoords = $othercoords->clump(1,2) if $othercoords->dims == 3;
    
    # Least squares fit of all coords in each complex
    my $trans = SBG::U::RMSD::superpose($selfcoords, $othercoords);
    # Now it has been transformed already. Can measure RMSD of new coords
    my $rmsd = SBG::U::RMSD::rmsd($selfcoords, $othercoords);
    $log->debug("Potential rmsd:", $rmsd, " via: ", join ' ', %$mapping);
    return wantarray ? ($trans, $rmsd) : $rmsd;
    
} # rmsd_mapping_backbone {





=head2 _realign

 Function: 
 Example : 
 Returns : 
 Args    : 



=cut
sub _realign {
    my ($aln, $selflabel, $otherlabel) = @_;

    # Determine PDB ID and chain ID to add to alignment
    my ($pdbid, $chainid) = $otherlabel =~ /$pdb41/;

    # Fetch the new sequence 
    my $dom = SBG::Domain->new(pdbid=>$pdbid,descriptor=>"CHAIN $chainid");
    my $seq = pdbseq($dom);
    # Reset the display ID
    $seq->display_id($pdbid . $chainid);

    # Add to alignment, clone it first (not done by factory already?)
    my $clustal = Bio::Tools::Run::Alignment::Clustalw->new(quiet=>1);
    $aln = clone($aln);
    $aln = $clustal->profile_align($aln,$seq);

    # Remove $selflabel from alignment
    $aln->remove_seq($aln->get_seq_by_id($selflabel));

    return $aln;

} # _realign


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
    my ($subjectkey) = $seqcoords->keys->grep(sub{ $_ ne $mappedkey })->flatten;

    # Convert pdb|1tim|AA to '1tima', returns a [ pdb, chain ] tuple
    my ($pdb_chain) = gi2pdbid($subjectkey);
    my $subjectkeyshort = join '', @$pdb_chain;

    my $labels = { 
        $querykey => $mappedkey, 
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
        my $resids = SBG::DB::res_mapping::query($pdbid, $chainid, $seqcoords);
        $resids or return;
        my $nfound = scalar @$resids;
        $ichop ||= $nfound;
        unless ($nfound == scalar(@$seqcoords)) {
            $log->error(
                "Could not extract all residue coordinates from $subjectkey");
            $ichop = min($ichop, $nfound, scalar @$seqcoords);
            $resids = $resids->slice([0..$ichop-1]);
        }

        # Note we start with the whole chain here but we're only extracting the
        # aligned residues. This will be the atomic representation. And since we
        # never use the Domain object itself, the fact that the descriptor
        # refers to the whole chain is not relevant.
        my $dom = SBG::Domain::Atoms->new(pdbid=>$pdbid,
                                          descriptor=>"CHAIN $chainid",
                                          residues=>$resids);
        # If this is the modelled domain, set it's frame of reference
        if ($key eq $subjectkeyshort) {
            my $trans = $self->get($querykey)->subject->transformation;
            $trans->apply($dom);
        }
        $coords->{$key} = $dom->coords;
    }

    # Force them to be the same dimensions by blatantly chopping the longer
    # This loses the 1-to-1 correspondance, but still aligns well if off by 1

    my $mapped_coords = $coords->{$mappedkey};
    my $subject_coords = $coords->{$subjectkeyshort};
    # Truncate both, simply from the end
    # May be off by a few residues, but should be better than giving up
    my $nchop = 
        min($ichop, $mapped_coords->dim(1), $subject_coords->dim(1)) - 1;
    $coords->{$subjectkeyshort} = $subject_coords->slice(":,0:$nchop");
    $coords->{$mappedkey} = $mapped_coords->slice(":,0:$nchop");

    # The subject is what was modelled, the query is the benchmark
    return $coords->{$subjectkeyshort}, $coords->{$mappedkey}
    
} # _coords_from_aln


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
} # _setcrosshairs



__PACKAGE__->meta->make_immutable;
no Moose;
1;


