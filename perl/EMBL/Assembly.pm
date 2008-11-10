#!/usr/bin/env perl

=head1 NAME

EMBL::Assembly - 

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

use strict;
use warnings;

use lib "..";

package EMBL::Assembly;

# use overload ();


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

    return $self;

} # new

# Add a Template (two domains) by linking 
sub add {
    my ($self, $template, $node) = @_;
    my $success = 0;

    return $success;
}




###############################################################################

1;

__END__
