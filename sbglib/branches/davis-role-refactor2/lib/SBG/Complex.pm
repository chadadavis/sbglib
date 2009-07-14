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

with 'SBG::Role::Storable';
with 'SBG::Role::Transformable';
with 'SBG::Role::Scorable';
with 'SBG::Role::Clonable';

use overload (
    '""' => 'stringify',
    fallback => 1,
    );


use Moose::Autobox;

use PDL::Lite;
use PDL::Core qw/pdl squeeze/;

use SBG::U::List qw/intersection mean/;
use SBG::U::Log qw/log/;
use SBG::U::RMSD;
use SBG::STAMP;


# Complex stores these data structures
use SBG::Superposition;
use SBG::Model;
use SBG::Interaction;

# For deriving a network from the Complex
use SBG::Seq;
use SBG::Node;
use SBG::Network;


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


################################################################################
=head2 models

 Function: Maps accession number of protein components to L<SBG::Model> model.
 Example : $cmplx->set('RRP43',
               new SBG::Model(query=>$myseq, subject=>$template_domain))
 Returns : The one L<SBG::Domain> modelling the protein, if any
 Args    : accession_number

Indexed by accession_number of L<SBG::Node> modelled by this L<SBG::Model>

=cut
has 'models' => (
    isa => 'HashRef[SBG::Model]',
    is => 'ro',
    lazy => 1,
    default => sub { {} },
    );


################################################################################
=head2 overlap_thresh

 Function: 
 Example : 
 Returns : 
 Args    : 

Allowable fractional overlap threshold for a newly added domain. If the domain
overlaps by more than this threshold with any domain already in the complex,
then it is rejected.

=cut
has 'overlap_thresh' => (
    is => 'rw',
    isa => 'Num',
    default => 0.5,
    );


################################################################################
=head2 domains

 Function: Extracts just the Domain objects from the Models in the Complex
 Example : 
 Returns : 
 Args    : 


=cut
sub domains {
    my ($self,) = @_;
    return $self->models->values->map(sub { $_->subject });

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
    return $self->models->keys;
}


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
sub network {
    my ($self) = @_;

    my $net = new SBG::Network;

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
                push(@nodes,new SBG::Node(new SBG::Seq(-accession_number=>$_)));
            }
        }
        $net->add($_) for @nodes;
        $net->add_interaction(
            -nodes=>[@nodes],-interaction=>$i);
    }

    return $net;
} 


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


TODO should be based on more than just fractional number of common components

=cut
sub coverage {
    my ($self, $other) = @_;

    warn "Not implemented";
    return 1.0 * $self->count / $other->count;

#     my @cnames = intersection($self->models->keys, $other->models->keys);

} # coverage


################################################################################
=head2 rmsd

 Function:
 Example :
 Returns : 
 Args    :

RMSD between common domains between this and another complex.

Models are associated by name. Models present in one complex but not the other
are not considered. Undefined when no common models.

TODO belongs in a ModelSet role

TODO test
=cut
sub rmsd {
   my ($self,$other) = @_;
   # Only consider common components
   my @cnames = intersection($self->models->keys, $other->models->keys);

   my @selflist = map { $self->get($_)->coords } @cnames;
   my @otherlist = map { $other->get($_)->coords } @cnames;

   my $selfcoords = pdl(@selflist)->squeeze;
   my $othercoords = pdl(@otherlist)->squeeze;

   return SGB::U::RMSD::rmsd($selfcoords, $othercoords);
}


################################################################################
=head2 attach

 Function: 
 Example : 
 Returns : Success, whether interaction can be added
 Args    : L<SBG::Interaction>


=cut
sub add_interaction {
    my ($self, $iaction, $srckey, $destkey) = @_;

    # Where the last reference domain for this component was placed in space
    my $refmodel = $self->get($srckey);
    my $refdom = $refmodel->subject if defined $refmodel;
    # Initial interaction, no spacial constraints yet, always accepted
    unless (defined $refdom) {
        $self->interactions->put($iaction, $iaction);
        # Extract Model objects from the Interaction
        $self->add_model(@{$iaction->models->values});
        return 1;
    }

    # Get domain models for components of interaction
    my $srcdom = $iaction->get($srckey)->subject;
    # Get a clone of this, because we will temporary manipulate it
    my $destdom = $iaction->get($destkey)->subject->clone;

    my $linker_superposition = SBG::STAMP::superposition($srcdom, $refdom);
    return 0 unless defined $linker_superposition;


    # Then apply that transformation to the interaction partner $destdom.
    # Product of relative with absolute transformation.
    # Order of application of transformations matters
    $linker_superposition->transformation->apply($destdom);
    # Any previous transformation (reference domain) has to also be included.
    $refdom->transformation->apply($destdom);


    # Now test steric clashes of potential domain against existing domains
    my $clashfrac = $self->check_clash($destdom);
    return 0 unless $clashfrac < 1.0;


    # Domain does not clash after being oriented, can be saved in complex now.
    # Save all meta data that went into this placement.
    # NB Any previous $self->get($destnode) gets overwritten. 
    # This is compatible with the backtracking of SBG::Traversal. 

    my $destmodel = new SBG::Model(
        query=>$iaction->get($srckey)->query,
        subject=>$destdom);
    $self->set($destkey, $destmodel);
    $self->clashes->put($destkey, $clashfrac);
    # Cache by destnode, as there may be many for any given refdom
    $self->superpositions->put($destkey, $linker_superposition);
    $self->interactions->put($iaction, $iaction);
    return 1;

} # add_interaction


################################################################################
=head2 check_clash

 Function:
 Example :
 Returns : 
 Args    :

Determine whether a given L<SBG::Domain> would create a clash/overlap in space
with any of the L<SBG::Domain>s in this complex.

=cut
sub check_clash {
    my ($self, $newdom) = @_;
    my $thresh = $self->overlap_thresh;
    my $overlaps = [];

    # Get all of the objects in this assembly. 
    # If any of them clashes with the to-be-added objects, then disallow
    foreach my $key (@{$self->models->keys}) {
        # Measure the overlap between $newdom and each component
        my $existingdom = $self->get($key)->subject;
        log()->trace("$newdom vs $existingdom");
        my $overlapfrac = $newdom->overlap($existingdom);
        # Nonetheless, if one clashes severely, bail out
        return 1 if $overlapfrac > $thresh;
        # Don't worry about domains that aren't overlapping at all (ie < 0)
        $overlaps->push($overlapfrac) if $overlapfrac > 0;
    }
    my $mean = mean($overlaps) || 0;
    log()->info("$newdom fits w/ mean overlap fraction: ", $mean);
    return $mean;
} 


################################################################################
__PACKAGE__->meta->make_immutable;
no Moose;
1;


