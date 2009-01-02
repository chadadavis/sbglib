#!/usr/bin/env perl

=head1 NAME

SBG::Assembly - Represents one solution to the problem of assembling a complex

=head1 SYNOPSIS

 use SBG::Assembly;


=head1 DESCRIPTION



=SEE ALSO

L<SBG::AssemblyIO> , L<SBG::Domain>

=cut

################################################################################

package SBG::Assembly;
use SBG::Root -Base, -XXX;

# This object is clonable
use base qw(Clone);

# Allowed (linear) overlap between the spheres, that represent the proteins
# Centre-of-mass + Radius-of-gyration
field 'clash';


use overload (
    '""' => 'asstring',
    'eq' => 'eq',
    );


################################################################################
=head2 new

 Title   : new
 Usage   : 
 Function: 
 Returns : 
 Args    : -clash Tolerance (angstrom) for overlaping radii of gyration

=cut
sub new () {
    my ($class, %o) = @_;
    my $self = { %o };
    bless $self, $class;
    $self->_undash;

    $self->{clash} = $config->val('assembly', 'clash') || '30';

    # Component L<SBG::Domain>s in this Assembly
    my $comp = {};
    # L<SBG::Interaction>s used in this Assembly
    my $iaction = {};

    return $self;
} # new


sub asstring {
    join ",", sort keys %{$self->{iaction}};
}

sub eq {
    my $other = shift;
    return "$self" eq "$other";
}


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
    super(shift || 2);
} # clone


# Number of components in this assembly
sub size {
    return scalar(keys %{$self->{comp}});
}


################################################################################
=head2 comp

 Title   : comp
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :

The component L<SBG::Domain> objects collected in this Assembly.  NB These also
contain centres-of-mass as well as Transform's

The return value of this method can be assigned to, e.g.:

 $assem->comp('mylabel') = $domainobject;

NB Spiffy doesn't magically create $self here, probably due to the attribute
=cut
sub comp : lvalue {
    my ($self,$key) = @_;
    # Do not use 'return' with 'lvalue'
    $self->{comp}{$key};
} # comp

sub iaction : lvalue {
    my ($self,$key) = @_;
    # Do not use 'return' with 'lvalue'
    $self->{iaction}{$key};
}

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
    my $newdom = shift;

    # Get all of the objects in this assembly. 
    # If any of them clashes with the to-be-added objects, then disallow
    foreach my $key (keys %{$self->{comp}}) {
        # Measure the overlap between $newdom and each component
        my $overlap = $newdom->overlap($self->comp($key));
        print STDERR 
            "\toverlap: ", $newdom->id, "/", $self->comp($key)->id, 
            " $overlap\n";
        if ($overlap > $self->clash) {
            print STDERR "\t$newdom clashes\n";
            return 1;
        }
    }
    print STDERR "\t$newdom fits\n";
    return 0;
} # clashes


################################################################################
1;
