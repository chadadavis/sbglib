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


use Moose::Autobox;

use PDL::Lite;
use PDL::Core qw/pdl squeeze zeroes sclr/;

use SBG::U::List qw/intersection mean sum flatten/;
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
# TODO DEL testing max paths:
#     default => 0.0,
#     default => 2,
    );


################################################################################
=head2 domains

 Function: Extracts just the Domain objects from the Models in the Complex
 Example : 
 Returns : ArrayRef[SBG::DomainI]
 Args    : 


=cut
sub domains {
    my ($self,) = @_;

    # Order of models attribute
    my $keys = $self->keys;
    return unless @$keys;

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
sub network {
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
                # TODO PROB always legit to use accession_number ?
                push(@nodes,
                     SBG::Node->new(SBG::Seq->new(-accession_number=>$_)));
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
=head2 rmsd

 Function:
 Example :
 Returns : 
 Args    :

RMSD between common domains between this and another complex.

Models are associated by name. Models present in one complex but not the other
are not considered. Undefined when no common models.

NB only works when complexes have same number of points

TODO belongs in a ModelSet role

=cut
sub rmsd {
   my ($self,$other) = @_;
   # Only consider common components
   my @cnames = $self->coverage($other);

   # make a copy before superposition
   my $selfcoords = $self->coords->copy;
   my $othercoords = $other->coords->copy;

   # NB only works if same number of points in both complexes
   my $transmatrix = SBG::U::RMSD::superpose($selfcoords, $othercoords);
   my $rmsd = SBG::U::RMSD::rmsd($selfcoords, $othercoords);

   return wantarray? ($rmsd, $transmatrix) : $rmsd;

} # rmsd


################################################################################
=head2 superposition

 Function: 
 Example : 
 Returns : 
 Args    : 

# TODO needs to be in some DomainSetI
# use $self->keys and $self->domains

=cut
sub superposition {
   my ($self,$other) = @_;
   # Only consider common components
   my @cnames = $self->coverage($other);

   # Pairwise Superpositions
   my $sups = [];
   my $rmsds = [];
   my $scs = [];
   foreach my $key (@cnames) {
       my $selfdom = $self->get($key)->subject;
       my $otherdom = $other->get($key)->subject;
       my $sup = SBG::STAMP::superposition($selfdom, $otherdom);
       next unless $sup;

       $sups->push($sup);
       $rmsds->push($sup->scores->at('RMS'));
       $scs->push($sup->scores->at('Sc'));
   }

   my $mats = $sups->map(sub{$_->transformation->matrix});
   my $summat = List::Util::reduce { our($a,$b); $a + $b } @$mats;

   # TODO BUG this causes a scaling as well
   my $avgmat = $summat / @$mats;

   my $rmsd = mean($rmsds);
   my $sc = mean($scs);

   return wantarray ? ($avgmat, $rmsd, $sc, $sups) : $avgmat;

} # superposition


# weighted averages of Sc scores
sub superposition_weighted {
   my ($self,$other) = @_;
   # Only consider common components
   my @cnames = $self->coverage($other);

   # Pairwise Superpositions
   my $sups = [];
   my $rmsds = [];
   my $scs = [];
   foreach my $key (@cnames) {
       my $selfdom = $self->get($key)->subject;
       my $otherdom = $other->get($key)->subject;
       my $sup = SBG::STAMP::superposition($selfdom, $otherdom);
       next unless $sup;

       $sups->push($sup);
       $rmsds->push($sup->scores->at('RMS'));
       $scs->push($sup->scores->at('Sc'));
   }

   my $scsum = sum($scs);

   my $mats = $sups->map(sub{$_->transformation->matrix});

   my $summat = zeroes(4,4);

   for (my $i = 0; $i < @$mats; $i++) {
       $summat += $mats->[$i] * ($scs->[$i] / $scsum);
   }

   my $avgmat = $summat;

   my $rmsd = mean($rmsds);
   my $sc = mean($scs);

   return wantarray ? ($avgmat, $rmsd, $sc, $sups) : $avgmat;

} # superposition_weighted


# To be called as $target->superposition_frame($model)
use SBG::Run::cofm qw/cofm/;

sub superposition_frame_cofm {
   my ($self,$other) = @_;
   # Only consider common components
   my @cnames = $self->coverage($other);

   # Pairwise Superpositions
   my $sups = [];
   my $rmsds = [];
   my $scs = [];

   foreach my $key (@cnames) {
       my $selfdom = $self->get($key)->subject;
       my $otherdom = $other->get($key)->subject;
       my $othernativedom = new SBG::Domain(pdbid=>$otherdom->pdbid,
                                            descriptor=>$otherdom->descriptor);
       $othernativedom = cofm($othernativedom);
       my $nativesup = SBG::STAMP::superposition($selfdom, $othernativedom);
       
       next unless $nativesup;

       # TODO All of this can be in another method: $c->setframe($othercomplex)

       # Set crosshairs
       $selfdom = cofm($selfdom);
       # Transform
       $nativesup->apply($selfdom);
       # Rebuild crosshairs over there
       $selfdom->_build_coords;
       # Reverse transform
       $nativesup->inverse->apply($selfdom);

       # After this, superpositioning $selfdom onto $otherdom should align
       # crosshairs

       # need to do this still? Should be identity anyway, nearly
       $selfdom->transformation->clear_matrix;
       # TODO Test here:


       # Now get the real superposition of $selfdom onto current location of
       # $otherdom
       my $sup = SBG::STAMP::superposition($selfdom, $otherdom);

       $sups->push($sup);
       $rmsds->push($sup->scores->at('RMS'));
       $scs->push($sup->scores->at('Sc'));
   }

   my $scsum = sum($scs);

   my $mats = $sups->map(sub{$_->transformation->matrix});

   my $summat = zeroes(4,4);

   for (my $i = 0; $i < @$mats; $i++) {
       $summat += $mats->[$i] * ($scs->[$i] / $scsum);
   }

   my $avgmat = $summat;

   my $rmsd = mean($rmsds);
   my $sc = mean($scs);

   return wantarray ? ($avgmat, $rmsd, $sc, $sups) : $avgmat;

} # superposition_frame_cofm


# Don't use the native orientation, just go right to where the model dom is
sub superposition_frame_cofm2 {
   my ($self,$other) = @_;
   # Only consider common components
   my @cnames = $self->coverage($other);

   # Pairwise Superpositions
   my $sups = [];
   my $rmsds = [];
   my $scs = [];

   foreach my $key (@cnames) {
       my $selfdom = $self->get($key)->subject;
       my $otherdom = $other->get($key)->subject;

       # Now get the real superposition of $selfdom onto current location of
       # $otherdom
       my $sup = SBG::STAMP::superposition($selfdom, $otherdom);
       
       next unless $sup;

       # TODO All of this can be in another method: $c->setframe($othercomplex)

       # Set crosshairs
       $selfdom = cofm($selfdom);
       # Transform
       $sup->apply($selfdom);
       # Rebuild crosshairs over there
       $selfdom->_build_coords;
       # Reverse transform
       $sup->inverse->apply($selfdom);

       # After this, superpositioning $selfdom onto $otherdom should align
       # crosshairs

       # need to do this still? Should be identity anyway, nearly
       $selfdom->transformation->clear_matrix;
       # TODO Test here:



       $sups->push($sup);
       $rmsds->push($sup->scores->at('RMS'));
       $scs->push($sup->scores->at('Sc'));
   }

   my $scsum = sum($scs);

   my $mats = $sups->map(sub{$_->transformation->matrix});

   my $summat = zeroes(4,4);

   for (my $i = 0; $i < @$mats; $i++) {
       $summat += $mats->[$i] * ($scs->[$i] / $scsum);
   }

   my $avgmat = $summat;

   my $rmsd = mean($rmsds);
   my $sc = mean($scs);

   return wantarray ? ($avgmat, $rmsd, $sc, $sups) : $avgmat;

} # superposition_frame_cofm2


# Don't use the native orientation, just go right to where the model dom is
# Requires resetting frame of ref of $self first
sub superposition_frame_cofm3 {
   my ($self,$other) = @_;
   # Only consider common components
   my @cnames = $self->coverage($other);

   # Pairwise Superpositions
   my $sups = [];
   my $rmsds = [];
   my $scs = [];

   foreach my $key (@cnames) {
       my $selfdom = $self->get($key)->subject;
       my $otherdom = $other->get($key)->subject;

       # Now get the real superposition of $selfdom onto current location of
       # $otherdom
       my $sup = SBG::STAMP::superposition($selfdom, $otherdom);
       
       next unless $sup;

       # TODO All of this can be in another method: $c->setframe($othercomplex)

       # Set crosshairs
       $selfdom = cofm($selfdom);
       # Transform
       $sup->apply($selfdom);
       # Rebuild crosshairs over there
       $otherdom->_build_coords;
       $selfdom->_build_coords;
       # Reverse transform
       $sup->inverse->apply($selfdom);

       # After this, superpositioning $selfdom onto $otherdom should align
       # crosshairs

       # need to do this still? Should be identity anyway, nearly
       $selfdom->transformation->clear_matrix;
       # TODO Test here:



       $sups->push($sup);
       $rmsds->push($sup->scores->at('RMS'));
       $scs->push($sup->scores->at('Sc'));
   }

   my $scsum = sum($scs);

   my $mats = $sups->map(sub{$_->transformation->matrix});

   my $summat = zeroes(4,4);

   for (my $i = 0; $i < @$mats; $i++) {
       $summat += $mats->[$i] * ($scs->[$i] / $scsum);
   }

   my $avgmat = $summat;

   my $rmsd = mean($rmsds);
   my $sc = mean($scs);

   return wantarray ? ($avgmat, $rmsd, $sc, $sups) : $avgmat;

} # superposition_frame_cofm3


# Try using (fixed) RMSD::superposition
# Still based on putting cofm in right frame of reference
sub superposition_points {
   my ($self,$other) = @_;
   # Only consider common components
   my @cnames = $self->coverage($other);
   unless (@cnames) {
       log()->error("No common components between complexes");
       return;
   }
   log()->trace(scalar(@cnames), " common components");

   my $selfcofms = [];
   my $othercofms = [];

   foreach my $key (@cnames) {
       my $selfdom = $self->get($key)->subject;
       my $otherdom = $other->get($key)->subject;
       $selfdom = _setcrosshairs($selfdom, $otherdom) or next;

       $selfcofms->push($selfdom);
       $othercofms->push(cofm($otherdom));
   }

   unless ($selfcofms->length > 1) {
       log->warn("Too few component-wise superpositions to superpose complex");
       return;
   }

   my $selfcoords = pdl($selfcofms->map(sub{ $_->coords }));
   my $othercoords = pdl($othercofms->map(sub{ $_->coords }));
   $selfcoords = $selfcoords->clump(1,2) if $selfcoords->dims == 3;
   $othercoords = $othercoords->clump(1,2) if $othercoords->dims == 3;

   my $trans = SBG::U::RMSD::superpose($selfcoords, $othercoords);
   log()->trace($trans);
   # Now it has been transformed already. Can measure RMSD of new coords
   my $rmsd = SBG::U::RMSD::rmsd($selfcoords, $othercoords);
   log()->debug("rmsd:", $rmsd);
   return wantarray ? ($trans, $rmsd) : $trans;

} # superposition_points


# set crosshairs of one domain, based on second
sub _setcrosshairs {
    my ($selfdom, $otherdom) = @_;

       # Now get the superposition from current $selfdom onto current $otherdom
       my $sup = SBG::STAMP::superposition($selfdom, $otherdom);
       return unless $sup;

       # Set crosshairs
       $selfdom = cofm($selfdom);
       # Transform
       $sup->apply($selfdom);
       # Rebuild crosshairs over there
       $selfdom->_build_coords;
# Why is $otherdom doing this? Esp. since otherdom isn't a new object!
#        $otherdom->_build_coords; 

    
       # Reverse transform. After this, superpositioning $selfdom onto $otherdom
       # should align crosshairs
       $sup->inverse->apply($selfdom);

       # need to do this still? Should be identity anyway, nearly
       $selfdom->transformation->clear_matrix;
       # TODO Test here:

    return $selfdom;
} # _setcrosshairs


sub superposition_frame {
   my ($self,$other) = @_;
   # Only consider common components
   my @cnames = $self->coverage($other);

   # Pairwise Superpositions
   my $sups = [];
   my $rmsds = [];
   my $scs = [];

   foreach my $key (@cnames) {
       my $selfdom = $self->get($key)->subject;
       my $otherdom = $other->get($key)->subject;
       my $othernativedom = new SBG::Domain(pdbid=>$otherdom->pdbid,
                                            descriptor=>$otherdom->descriptor);
       my $nativesup = SBG::STAMP::superposition($selfdom, $othernativedom);

       next unless $nativesup;

       # TODO All of this can be in another method: $c->setframe($othercomplex)


       # Inverse of the rotation matrix (no translation)
       # Will define the orientation of the crosshairs, relative to $nativedom
       my $invrotmat = $nativesup->transformation->rotation->inverse;

       # After this, superpositioning $selfdom onto $otherdom should align
       # crosshairs
       $invrotmat->apply($selfdom);
       # Now pretend we were never transformed
       $selfdom->transformation->clear_matrix;
       # TODO Test here:


       # Now get the real superposition of $selfdom onto current $otherdom
       my $sup = SBG::STAMP::superposition($selfdom, $otherdom);

       $sups->push($sup);
       $rmsds->push($sup->scores->at('RMS'));
       $scs->push($sup->scores->at('Sc'));
   }

   my $scsum = sum($scs);

   my $mats = $sups->map(sub{$_->transformation->matrix});

   my $summat = zeroes(4,4);

   for (my $i = 0; $i < @$mats; $i++) {
       $summat += $mats->[$i] * ($scs->[$i] / $scsum);
   }

   my $avgmat = $summat;

   my $rmsd = mean($rmsds);
   my $sc = mean($scs);

   return wantarray ? ($avgmat, $rmsd, $sc, $sups) : $avgmat;

} # superposition_frame



################################################################################
=head2 merge

 Function: Combines all of the domains in this complex into a single domain
 Example : 
 Returns : 
 Args    : 

TODO put in a DomainSetI

=cut
use SBG::DomainIO::pdb;
use Module::Load;
sub merge {
    my ($self,$file) = @_;
    my $doms = $self->domains or return;
    my $io = $file ?
        new SBG::DomainIO::pdb(file=>">$file") :
        new SBG::DomainIO::pdb(tempfile=>1);
    $io->write(@$doms);
    my $type = ref $doms->[0];
    load($type);
    my $dom = $type->new(file=>$io->file, descriptor=>'ALL');
    return $dom;
} # merge


################################################################################
=head2 add_interaction

 Function: 
 Example : 
 Returns : Success, whether interaction can be added
 Args    : L<SBG::Interaction>


=cut
sub add_interaction {
    my ($self, $iaction, $srckey, $destkey) = @_;

    my $type = $self->objtype;

    # Where the last reference domain for this component was placed in space
    my $refmodel = $self->get($srckey);
    my $refdom = $refmodel->subject if defined $refmodel;
    # Initial interaction, no spacial constraints yet, always accepted
    unless (defined $refdom) {
        my $keys = $iaction->keys;
        my $models = $keys->map(sub{$self->_mkmodel($iaction, $_)});
        $self->add_model(@$models);
        $self->interactions->put($iaction, $iaction);
        return 1;
    }

    # Get domain models for components of interaction
    my $srcdom = $iaction->get($srckey)->subject;
    # For domain being placed, make a copy that has a concrete representation
    my $destmodel = $self->_mkmodel($iaction, $destkey);
    my $destdom = $destmodel->subject;

    my $linker_superposition = SBG::STAMP::superposition($srcdom, $refdom);
    return 0 unless defined $linker_superposition;


    # Then apply that transformation to the interaction partner $destdom.
    # Product of relative with absolute transformation.
    # Order of application of transformations matters
    $linker_superposition->transformation->apply($destdom);
    log()->trace("Linking:", $linker_superposition->transformation);

    # Now test steric clashes of potential domain against existing domains
    my $clashfrac = $self->check_clash($destdom);
    return 0 unless $clashfrac < 1.0;


    # Domain does not clash after being oriented, can be saved in complex now.
    # Save all meta data that went into this placement.
    # NB Any previous $self->get($destnode) gets overwritten. 
    # This is compatible with the backtracking of SBG::Traversal. 
    $self->set($destkey, $destmodel);
    $self->clashes->put($destkey, $clashfrac);
    # Cache by destnode, as there may be many for any given refdom
    $self->superpositions->put($destkey, $linker_superposition);
    $self->interactions->put($iaction, $iaction);
    return 1;

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
    my $cdom = cofm($clone);

    my $model = new SBG::Model(
        query=>$vmodel->query, subject=>$cdom, scores=>$vmodel->scores);

    return $model;
}


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
    log()->debug("fractional overlap thresh:$thresh");
    my $overlaps = [];

    log()->trace("$newdom vs " . $self->models->values->join(','));
    # Get all of the objects in this assembly. 
    # If any of them clashes with the to-be-added objects, then disallow
    foreach my $key (@{$self->keys}) {
        # Measure the overlap between $newdom and each component
        my $existingdom = $self->get($key)->subject;
        log()->trace("$newdom vs $existingdom");
        my $overlapfrac = $newdom->overlap($existingdom);
        # Nonetheless, if one clashes severely, bail out
        return 1 if $overlapfrac > $thresh;
        # Ignore domains that aren't overlapping at all (ie < 0)
        $overlaps->push($overlapfrac) if $overlapfrac > 0;
    }
    my $mean = mean($overlaps) || 0;
    log()->info("$newdom fits w/ mean overlap fraction: ", $mean);
    return $mean;
} # check_clash


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
=head2 globularity

 Function: 
 Example : 
 Returns : [0,1]
 Args    : 

Estimates the extent of globularity of a complex as a whole as the ratio of the
rradius of gyration to the maximum radius, over all of the coordinates in the
complex.

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
__PACKAGE__->meta->make_immutable;
no Moose;
1;


