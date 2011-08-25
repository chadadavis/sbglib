#!/usr/bin/env perl

=head1 NAME

SBG::Role::Clonable - Role implementing B<Storable::dclone>

=head1 SYNOPSIS

 with 'SBG::Role::Clonable';
 with 'SBG::Role::Clonable' => { depth => 2 }; # default

=head1 DESCRIPTION


=head1 SEE ALSO

L<Storable>

=cut

package SBG::Role::Clonable;
use Moose::Role;

use Storable qw/dclone/;

=head2 clone

 Function: 
 Example : 
 Returns : 
 Args    : 

Calls 

 Storable::dclone($self)

which allows one to define hooks for Storable to override the default cloning.

=cut

sub clone {
    my ($self) = @_;
    return dclone($self);
}

no Moose::Role;
1;

