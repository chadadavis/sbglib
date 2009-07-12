#!/usr/bin/env perl

=head1 NAME

SBG::Interface - 

=head1 SYNOPSIS

 use SBG::Interface;

=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::DomainI>

=cut

################################################################################

package SBG::Interface;
use Moose;

use Moose::Autobox;

use List::MoreUtils qw/all/;

use overload (
    '""' => 'stringify',
    '==' => 'equal',
    fallback => 1,
    );


################################################################################
=head2 domains

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
has 'domains' => (
    is => 'rw',
    isa => 'HashRef',
    lazy => 1,
    default => sub { {} },
    handles => [ qw/at put delete keys values/ ],
    );



sub stringify {
    my ($self) = @_;
    # Stringify the domains
    my @strings = $self->values->sort->map( sub { "$_" } );
    return join('/',@strings);
}


sub equal {
    my ($self, $other) = @_;
    # Set equality, sort the lists first
    my $ours = $self->values->sort;
    my $theirs = $other->values->sort;
    # Componentwise equality, only if all (two) are true
    return all { $ours->[$_] == $theirs->[$_] } (0..1);
}


################################################################################
__PACKAGE__->meta->make_immutable;
no Moose;
1;

