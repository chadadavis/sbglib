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

################################################################################

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
use List::MoreUtils qw/mesh/;

use PDL::Lite;
use PDL::Core qw/pdl squeeze zeroes sclr/;
use Log::Any qw/$log/;
use bignum; # qw/inf/;

use Algorithm::Combinatorics qw/variations/;

use SBG::U::List 
    qw/interval_overlap intersection mean sum flatten swap cartesian_product/;
use SBG::U::RMSD;
use SBG::U::iRMSD; # qw/irmsd/;
use SBG::STAMP; # qw/superposition/
use SBG::Superposition::Cache; # qw/superposition/;

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

use Module::Load;


################################################################################
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


################################################################################
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


################################################################################
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



################################################################################
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


################################################################################
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


################################################################################
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


################################################################################
=head2 clashes

Fractional overlap/clash of each domain when it was added to the complex. This
is not updated when subsequent domains are added. This has the nice side-effect
that overlaps are not double-counted. Each domain stores the clashes it
encounted at the time it was added.

E.g attach(A), attach(B), attach(C). If A and C clash, A won't know about it,
but C will have saved it, having been added subsequently.

Indexed by the L<SBG::Node> creating the clashes when it was added.

=cut
has 'clashes' => (
    isa => 'HashRef[Num]',
    is => 'ro',
    lazy => 1,
    default => sub { { } },
    );
# TODO each clash should be saved is the 'scores' hash of the Superposition


################################################################################
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



################################################################################
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


################################################################################
=head2 score

 Function: 
 Example : 
 Returns : 
 Args    : 


Combined score of all domain models in a complex

=cut
has 'score' => (
    is => 'rw',
    isa => 'Num',
    lazy_build => 1,
    );

sub _build_score {
    my ($self) = @_;

    my $models = $self->models->values;

    # Sequence coverage, average
    my $covers = $models->map(sub{$_->coverage});
    my $pseqlength = $covers->sum / $covers->length;


    # Interactions in model
    my $miactions = $self->interactions->values;
    # Edge weight, generally the seqid
    my $weights = $miactions->map(sub{$_->weight})->grep(sub{defined $_});
    # Average sequence identity of all the templates.
    # NB linker domains are counted multiple times. 
    # Given a hub proten and three interacting spoke proteins, there are not 4
    # values for sequence identity, but rather 6=2*(3 interactions)
    my $avg_iaction = $weights->sum / $weights->length;


    # Linker superpositions required to build model by overlapping dimers
    my $sups = $self->superpositions->values;
    my $scs = $sups->map(sub{$_->scores->at('Sc')});
    # Average Sc of all superpositions done
    my $msc = $scs->sum / $scs->length;
    # Scale [0,100]
    $msc *= 10;

    my $glob = 100 * $self->globularity;

    # Score weights
    my ($wtcover, $wtiaction, $wtsc, $wtglob) = (.1, .4, .3, .2);
    # Score ranges
    my @ranges;

    # Scale to [0,100]
    my $score = 100 * sum(
        $wtcover*$pseqlength,
        $wtiaction*$avg_iaction**2,
        $wtsc*$msc**2,
        $wtglob*$glob,
        ) / sum(
        $wtcover*100,
        $wtiaction*100**2,
        $wtsc*100**2,
        $wtglob*100,
        );
    
    return $score;
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


################################################################################
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


################################################################################
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


################################################################################
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


################################################################################
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


################################################################################
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


################################################################################
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
        $net->add($_) for @nodes;
        $net->add_interaction(
            -nodes=>[@nodes],-interaction=>$i);
    }

    return $net;
} # network


################################################################################
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


################################################################################
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


################################################################################
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


################################################################################
=head2 globularity

 Function: 
 Example : 
 Returns : [0,1]
 Args    : 

Estimates the extent of globularity of a complex as a whole as the ratio of the
rradius of gyration to the maximum radius, over all of the coordinates in the
complex (which may be all atoms, just residues, just centres-of-mass, etc)

This provides some measure of how compact, non-linear, the components in a
complex are arranged. E.g. high for an exosome, low for actin fibers

=cut
sub globularity {
    my ($self,) = @_;

    my $pdl = $self->coords;
    my $centroid = SBG::U::RMSD::centroid($pdl);

    my $radgy = SBG::U::RMSD::radius_gyr($pdl, $centroid);
    my $radmax = SBG::U::RMSD::radius_max($pdl, $centroid);

    # Convert PDL to scalar
    return ($radgy / $radmax);

} # globularity


################################################################################
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


################################################################################
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


################################################################################
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


################################################################################
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
    my $irmsd = SBG::U::iRMSD::irmsd($self->domains($keys), 
                                     $iaction->domains($keys));
    return $irmsd;

} # cycle


################################################################################
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


################################################################################
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
        );

    return $model;
} # _mkmodel


################################################################################
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


################################################################################
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


################################################################################
=head2 overlap

 Function: 
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



################################################################################
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


# Determine bijection by testing all combinations in homologous classes
# If one complex is modelling the other, call this as $model->rmsd($benchmark)
sub rmsd_class {
    my ($self,$other) = @_;
    
    # Upper sentinel for RMSD
    my $maxnum = inf();
    my $bestrmsd = $maxnum;
    my $besttrans;
    my $bestmapping;
    
    # The complex model knows the symmetry of the components being built, even
    # the ones that were not explicitly modelled in this complex.
    # Group components into homologous classes (a component is in just one class)
    my @cc = $self->symmetry->connected_components();

    # The components actually being modelled in this complex, sorted by class,
    # since we about to generate permutations of each class. The order of the
    # classes in @cc must be the same as the order of classes in $model I.e. if
    # class [B E] is first in @cc, then any B or E present must also be first in
    # $model
    my $keys = $self->keys;
    my $model = [ map { _members_by_class($_, $keys) } @cc ];
    

    # Permute all members within each class, based on members present in model
    my @class_variations = class_variations(\@cc, $model);
    # Cartesian product of all possibilities of each class of homologs
    my @carts = cartesian_product(@class_variations);
    foreach my $cart (@carts) {
        my @cart = flatten $cart;
        # Map each component present to a possible component in the benchmark
        my %mapping = mesh(@$model, @cart);
        
        # Test this mapping
        my ($trans, $rmsd) = rmsd_mapping($self, $other, $model, \%mapping);
        $log->debug("rmsd:", $rmsd || 'undef');
        $log->debug("bestrmsd:", $bestrmsd||'undef');
        $log->debug("rmsd<bestrmsd:", 
                    defined($rmsd) && defined($bestrmsd) && $rmsd<$bestrmsd);
        next unless defined $rmsd;
        if (! defined($bestrmsd) || $rmsd < $bestrmsd) {
            $bestrmsd = $rmsd;
            $besttrans = $trans;
            $bestmapping = \%mapping;
            $log->debug("better rmsd:$rmsd via: @cart");
        }

    }
    if ($bestrmsd < $maxnum) {
        $log->info("best rmsd:$bestrmsd via: ", join ' ', %$bestmapping);
        $self->correspondance($bestmapping);
    } else {
        $bestrmsd = 'NaN';
    }
    
    return wantarray ? ($besttrans, $bestrmsd, $bestmapping) : $bestrmsd;
    
} # rmsd_class


# $class is an array of arrays. Each array contains the members of a class
# The $model contains those members, over all classes, which are actually present
sub class_variations {
    my ($classes, $model) = @_;

    my @class_variations;
    foreach my $class (@$classes) {
        # Get members of this class that are present in model
        my @present = _members_by_class($class, $model);
        # All nPk permutations of $k elements of this class
        my @variations = variations($class, scalar(@present));
        push @class_variations, \@variations;
    }
    return @class_variations;
}


#
sub _members_by_class {
    my ($class, $members) = @_;
    # Stringify (in case of objects)
    $class = [ map { "$_" } @$class ];
    my @present = grep { my $c=$_; grep { $_ eq $c  } @$members } @$class;
    return wantarray ? @present : \@present;
}


# Do RMSD of domains with the given label mapping
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

   my $trans = SBG::U::RMSD::superpose($selfcoords, $othercoords);
   # Now it has been transformed already. Can measure RMSD of new coords
   my $rmsd = SBG::U::RMSD::rmsd($selfcoords, $othercoords);
   $log->debug("one rmsd:", $rmsd, " via: ", join ' ', %$mapping);
   return wantarray ? ($trans, $rmsd) : $rmsd;

} # rmsd_mapping


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


################################################################################
__PACKAGE__->meta->make_immutable;
no Moose;
1;


