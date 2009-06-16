#!/usr/bin/env perl

=head1 NAME

SBG::Domain - Represents a domain of a protein structure. 

=head1 SYNOPSIS

 use SBG::Domain;

=head1 DESCRIPTION

A generic class that implements only the L<SBG::DomainI> interface

=head1 SEE ALSO

L<SBG::DomainI>

=cut

################################################################################

package SBG::Domain;
use Moose;

use Carp qw/cluck/;

# Defines what must be implemented to represent a 3D structure
with qw/
SBG::DomainI 
/;


use overload (
    '""' => 'stringify',
    '==' => 'equal',
    fallback => 1,
    );


sub overlap {
    cluck "overlap() not implemented in " . __PACKAGE__;
    return;
}


################################################################################
__PACKAGE__->meta->make_immutable;
1;

