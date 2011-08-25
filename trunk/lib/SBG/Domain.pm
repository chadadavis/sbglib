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

package SBG::Domain;
use Moose;

# Defines what must be implemented to represent a 3D structure
with qw/
    SBG::DomainI
    /;

# Implemntations are in DomainI
use overload (
    '""'     => 'stringify',
    '=='     => 'equal',
    fallback => 1,
);

use Log::Any qw/$log/;

=head2 overlap

 Function: Not defined
 Example : 
 Returns : N/A
 Args    : N/A


=cut

sub overlap {
    $log->warn("overlap() not defined by " . __PACKAGE__);
    return;
}

=head2 centroid

 Function: 
 Example : 
 Returns : NA
 Args    : 

=cut

sub centroid {
    my ($self,) = @_;
    warn "Not implemented";
    return;
}    # centroid

__PACKAGE__->meta->make_immutable;
no Moose;
1;

