#!/usr/bin/env perl

=head1 NAME

EMBL::Sphere - 

=head1 SYNOPSIS


=head1 DESCRIPTION



=head1 BUGS

None known.

=head1 REVISION

$Id: Prediction.pm,v 1.33 2005/02/28 01:34:35 uid1343 Exp $

=head1 APPENDIX

Details on functions implemented here are described below.
Private internal functions are generally preceded with an _

=cut

################################################################################

use lib "..";
use EMBL::Point;


package EMBL::Sphere;

use overload (
    '-' => 'difference',
    );



################################################################################
=head2 new

 Title   : new
 Usage   : 
 Function: 
 Returns : 
 Args    :

=cut

sub new {
    my ($class, @args) = @_;
    my $self = {};
    bless $self, $class;

    $self->{centre} = $self->{center} = new EMBL::Point(@args);
    $self->{radius} = $args[3] || 0;

    return $self;

} # new


################################################################################
=head2 difference

 Title   : difference
 Usage   : 
 Function: 
 Returns : 
 Args    : 

=cut

sub difference {
    my ($self, $obj) = @_;

    return $self->radius + $obj->radius - ($self->centre - $obj->centre);

} # add_template


# Similar, but requires no sqrt calculation (which could be costly)
sub overlaps {
    my ($self, $obj, $thresh) = @_;
    $thresh ||= 0;
    my $sqdist = 
            sq($self->centre->x - $obj->centre->x) + 
            sq($self->centre->y - $obj->centre->y) +
            sq($self->centre->z - $obj->centre->z);
    my $radii = $self->radius + $obj->radius;
    return $sqdist + $thresh <= $radii * $radii;
}


################################################################################
=head2 AUTOLOAD

 Title   : AUTOLOAD
 Usage   : $obj->member_var($new_value);
 Function: Implements get/set functions for member vars. dynamically
 Returns : Final value of the variable, whether it was changed or not
 Args    : New value of the variable, if it is to be updated

Overrides built-in AUTOLOAD function. Allows us to treat member vars. as
function calls.

=cut

sub AUTOLOAD {
    my ($self, $arg) = @_;
    our $AUTOLOAD;
    return if $AUTOLOAD =~ /::DESTROY$/;
    my ($pkg, $file, $line) = caller;
    $line = sprintf("%4d", $line);
    # Use unqualified member var. names,
    # i.e. not 'Package::member', rather simply 'member'
    my ($field) = $AUTOLOAD =~ /::([\w\d]+)$/;
    $self->{$field} = $arg if defined $arg;
    return $self->{$field} || '';
} # AUTOLOAD


###############################################################################

1;

__END__
