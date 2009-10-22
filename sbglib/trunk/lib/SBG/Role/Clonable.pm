#!/usr/bin/env perl

=head1 NAME

SBG::Role::Clonable - Role implementing B<Clone::clone>

=head1 SYNOPSIS

 with 'SBG::Role::Clonable';

 with 'SBG::Role::Clonable' => { depth => 2 }; # default

But not like:

 with qw/
 SBG::Role::Clonable
 Some::Other::Role
 /;

I.e. the B<with> needs to be called independently for parameterized roles

=head1 DESCRIPTION

Depth 2 means that the object and it's pointers will be copied by value.

E.g. 

 $a = { name => 'joe', mymap => { 'age' => 50, 'hands' => 2} };
 $b = $a->clone();

Then $a{'mymap'} and $b{'mymap'} are both references to one hash, and changing
the one changes the other.

=head1 SEE ALSO

L<Clone>

=cut

################################################################################

package SBG::Role::Clonable;
use MooseX::Role::Parameterized;

use Clone qw/clone/;


=head2 depth

Clone depth, default 2.

=cut
parameter 'depth' => (
    isa => 'Int',
    default => 2,
    );


role {
    my $params = shift;

    has 'clonedepth' => (
        is => 'rw',
        isa => 'Int',
        default => $params->depth,
        );

    method 'clone' => sub {
        my ($self, $depth) = @_;
        $depth //= $self->clonedepth();
        # Depth 2 means: copy the object (1) and the hashes/objects in it (2).
        # Does not copy what is referenced in/from those hashes/objects (3).
        return Clone::clone($self, $depth);
    }; # clone
    
}; # role

################################################################################
no Moose::Role;
1;


