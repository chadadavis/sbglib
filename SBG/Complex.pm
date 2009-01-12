#!/usr/bin/env perl

=head1 NAME

SBG::Complex - Represents one solution to the problem of assembling a complex

=head1 SYNOPSIS

 use SBG::Complex;


=head1 DESCRIPTION

A state-holder for L<SBG::Traversal>. Also provides the call-back functions
needed by L<SBG::Traversal>. In short, an L<SBG::Complex> is one of many
solutions to the protein complex assembly problem for a give set of proteins.

=SEE ALSO

L<SBG::ComplexIO> , L<SBG::Domain>

=cut

################################################################################

package SBG::Complex;
use SBG::Root -base;

# This object is clonable
use base qw(Clone);

use SBG::Domain qw(sqdist);
use SBG::CofM;
use SBG::STAMP;

use overload (
    '""' => '_asstring',
    'eq' => '_eq',
    '-'  => 'rmsd',
    );


################################################################################
# Fields and accessors


# Allowed (linear) overlap between the spheres, that represent the proteins
# Centre-of-mass + Radius-of-gyration
field 'overlapthresh';


################################################################################
=head2 comp

 Title   : comp
 Usage   : $assem->comp('mylabel') = $domainobject;
 Function: 
 Example : $assem->comp('mylabel') = $domainobject;
 Returns : An (lvalue) ref to the L<SBG::Domain> for the component name given
 Args    :

A L<SBG::Domain> also contains a centre-of-mass point and possibly an associated
L<SBG::Transform>

These saved domains are used to lookup previously determined frames of
reference. This is necessary because domains are transformed in space throughout
the traversal. 

=cut
# NB Spiffy doesn't magically create $self here, probably due to the attribute
sub comp : lvalue {
    my ($self,$key) = @_;
    $self->{comp} ||= {};
    # Do not use 'return' with 'lvalue'
    $self->{comp}{$key};
} # comp

# TODO DOC
# TODO save just the IDs or the actual objects, or both?
# Well, it's a hash, index the objects by the ID !
sub iaction : lvalue {
    my ($self,$key) = @_;
    $self->{iaction} ||= {};
    # Do not use 'return' with 'lvalue'
    $self->{iaction}{$key};
}


################################################################################
# Public

################################################################################
=head2 new

 Title   : new
 Usage   : 
 Function: 
 Returns : 
 Args    : -overlapthresh Tolerance (angstrom) for overlaping radii of gyration

=cut
sub new () {
    my ($class, %o) = @_;
    my $self = { %o };
    bless $self, $class;
    $self->_undash;

    $self->{overlapthresh} = $config->val('assembly', 'overlapthresh') || '30';

    return $self;
} # new


################################################################################
=head2 clone

 Title   : clone
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :

A shallow copy, copies hashes and their pointers.  Doesn't copy referenced
Domain/Transform objects.  This is necessary, as backtracking graph traversal
creates many Assemblys.

Depth 2 means: copy assembly (1) and the hashes/objects in Assembly (2).  Does
not copy what is referenced in/from the hashes/objects (3).

I.e. Assembly can efficiently contain references to other objects without
incurring a cloning copy penalty.

=cut
sub clone {
    my $self = shift;
    return $self->Clone::clone(shift || 2);
} # clone


################################################################################
=head2 size

 Title   : size
 Usage   : $assembly->size;
 Function: Number of components in the current Assembly
 Example : $assembly->size;
 Returns : ents in the current Assembly
 Args    : NA


=cut
sub size {
    my $self = shift;
    return scalar(keys %{$self->{comp}});
}


################################################################################
=head2 add

 Title   : add
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :

Add a L<SBG::Domain> to this complex, indexed by it's 'label' field.
Access them using 

 L<comp>("yourlabel");

NB If two domains have the same label, the latter will overwrite the former

=cut
sub add {
   my ($self,@doms) = @_;
   for (@doms) {
       $self->comp($_->label) = $_;
   }
} # add


################################################################################
=head2 clashes

 Title   : clashes
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :

Determine whether a given L<SBG::Domain> (containing a centre-of-mass with a
radius of gyration), would create a clash/overlap in space with any of the
L<SBG::Domain>s in this Assembly.

=cut
sub clashes {
    my ($self, $newdom) = @_;
    $logger->trace("Checking $newdom at thresh: ", $self->overlapthresh);
    # Get all of the objects in this assembly. 
    # If any of them clashes with the to-be-added objects, then disallow
    foreach my $key (keys %{$self->{comp}}) {
        # Measure the overlap between $newdom and each component
        my $existingdom = $self->comp($key);
        $logger->trace("$newdom vs $existingdom");
        
        if ($newdom->overlaps($existingdom, $self->overlapthresh)) {
            $logger->info("$newdom clashes w/ existing $existingdom");
            return 1;
        }
    }
    $logger->info("$newdom fits");
    return 0;
} # clashes


################################################################################
=head2 transform

 Title   : transform
 Usage   :
 Function: Transforms each component L<SBG::Domain> by a given L<SBG::Transform>
 Example :
 Returns : 
 Args    :


=cut
sub transform {
   my ($self,$trans) = @_;
   foreach my $name ($self->names) {
       $self->comp($name)->transform($trans);
   }

} # transform


################################################################################
=head2 min_rmsd

 Title   : min_rmsd
 Usage   :
 Function:
 Example :
 Returns : minrmsd, mintrans, minname
 Args    :

NB; this will only work if the $truth hasn't yet been transformed.

Because it relies on being able to put the complex $truth into the frame of
reference of the template domains used to build the $model complex. 

=cut
sub min_rmsd {
    my ($model, $truth) = @_;
    my $minrmsd;
    my $mintrans;
    my $minname;
    my $names = SBG::Root::reorder([$model->names, $truth->names]);
    foreach my $name (@$names) {
        # Only consider common components
        my $mdom = $model->comp($name);
        my $tdom = $truth->comp($name);
        $logger->info("Missing $name from model") unless $mdom;
        $logger->info("Additional $name in model") unless $tdom;
        next unless $mdom && $tdom;
        $logger->trace("Joining on: $name");
        my $trans = superpose($tdom, $mdom);
        # Product of these transformations: (applying $trans, then from $mdom)
        $trans = $mdom->transformation * $trans;
        $truth->transform($trans);
        $logger->debug("Resulting RMSD on $name: ", $mdom - $tdom);
        my $rmsd = $model - $truth;
        $logger->debug("Resulting RMSD on complex: $rmsd");
        # Don't forget to reset back to original frame of reference
        $truth->transform($trans->inverse);

        if (!defined($mindrmsd) || $rmsd < $minrmsd) {
            $minrmsd = $rmsd;
            $mintrans = $trans;
            $minname = $name;
        }
    }
    $logger->debug("Min RMSD: $mindrmsd ($minname)");
    return $minrmsd unless wantarray;
    return $minrmsd, $mintrans, $minname
} # min_rmsd


################################################################################
=head2 asarray

 Title   : asarray
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :

Return all the L<SBG::Domain>s contained in this complex

=cut
sub asarray {
   my ($self,@args) = @_;
   return sort { $a->label cmp $b->label } values %{$self->{comp}};
} # asarray


################################################################################
=head2 names

 Title   : names
 Usage   :
 Function:
 Example :
 Returns : Names (i.e. 'label') of all component L<SBG::Domain>s, sorted
 Args    :


=cut
sub names {
   my ($self,@args) = @_;
   return sort keys %{$self->{comp}};
}


################################################################################
=head2 rmsd

 Title   : rmsd
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :

Average RMSD between mapped (by label) component Domains
Undefined when no common component domains.

=cut
sub rmsd {
   my ($self,$other) = @_;
   my $count;
   my $sum;
   foreach my $name ($self->names) {
       my $c1 = $self->comp($name);
       my $c2 = $other->comp($name);
       next unless defined($c1) && defined($c2);
       $cofm1 = $c1->cofm;
       $cofm2 = $c2->cofm;
       next unless 
           defined($cofm1) && defined($cofm2) && $cofm1->dims == $cofm2->dims;

       my $sqdist = SBG::Domain::sqdist($cofm1, $cofm2);
       $sum += $sqdist;
       $count++;
   }
   return sqrt($sum / $count);
}


################################################################################
# Private

sub _asstring {
    my $self = shift;
    join ",", sort keys %{$self->{iaction}};
}


sub _eq {
    my $self = shift;
    my $other = shift;
    return "$self" eq "$other";
}


################################################################################
1;


__END__

