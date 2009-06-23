#!/usr/bin/env perl

=head1 NAME

SBG::Domain - Represents a domain of a protein structure. 

=head1 SYNOPSIS

 use SBG::Domain;

=head1 DESCRIPTION

A generic class that implements only the L<SBG::DomainI> interface with no
particular implementation.

=head1 SEE ALSO

L<SBG::DomainI>

=cut

################################################################################

package SBG::Domain;
use Moose;

use SBG::U::Log qw/log/;


# Defines what must be implemented to represent a 3D structure
with qw/
SBG::DomainI 
/;


use overload (
    '""' => 'stringify',
    '==' => 'equal',
    fallback => 1,
    );


################################################################################
=head2 overlap

 Function: Not defined
 Example : 
 Returns : N/A
 Args    : N/A


=cut
sub overlap {
    log()->warn("overlap() not defined by " . __PACKAGE__);
    return;
}


################################################################################
__PACKAGE__->meta->make_immutable;
no Moose;
1;

