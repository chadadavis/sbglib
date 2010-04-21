#!/usr/bin/env perl

=head1 NAME

SBG::Role::Similar - 

=head1 SYNOPSIS

with 'SBG::Role::Similar';

sub similar {
    my ($self, $other) = @_;
    return $self->length == $other->length;
}
    
=head1 DESCRIPTION

An role for identifying objects capable of comparing themselves to each other.

=head1 SEE ALSO

L<Clone>

=cut



package SBG::Role::Similar;
use Moose::Role;



=head2 similar

 Function: Measures similarity to another instance
 Example : my $similarity = $obj_a->similar($obj_b);
 Returns : A number between [0,1]
 Args    : Another instance of the same class/interface


=cut
requires 'similar';



no Moose::Role;
1;


