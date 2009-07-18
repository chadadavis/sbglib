#!/usr/bin/env perl

=head1 NAME

SBG::Role::Scorable - 

=head1 SYNOPSIS

with 'SBG::Role::Scorable';

=head1 DESCRIPTION


=head1 SEE ALSO


=cut

################################################################################

package SBG::Role::Scorable;
use Moose::Role;


################################################################################
=head2 scores

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
has 'scores' => (
    is => 'rw',
    isa => 'HashRef',
    lazy => 1,
    default => sub { {} },
    );


################################################################################
no Moose::Role;
1;


