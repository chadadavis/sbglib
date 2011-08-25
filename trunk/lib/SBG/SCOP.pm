#!/usr/bin/env perl

=head1 NAME

SBG::SCOP - Utilities for working with SCOP, a functional interface

=head1 SYNOPSIS

 use SBG::SCOP;

=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::U::DB>

=cut

package SBG::SCOP;
use base qw/Exporter/;

our @EXPORT_OK = qw(pdb2scop lca equiv parse_scopid get_descriptor);

use strict;
use warnings;
use List::MoreUtils qw(each_arrayref all);

=head2 lca

 Function: Lowest common ancestor of multiple SCOP codes
 Example : 
 Returns : longest common prefix of multiple SCOP strings.
 Args    : 

E.g. 
qw(a.3.2.2 a.3.4.5 a.3.4.1) => a.3
qw(a.3.2.2-1 a.3.2.2-1) => a.3.2.2-1
qw(a.3.2.2-1 a.3.2.2-2) => a.3.2.2

=cut

sub lca {
    my @classes = map { [ split(/[.-]/) ] } @_;
    my @lca;
    my $ea = each_arrayref(@classes);
    while (my @a = $ea->()) {
        my $x = $a[0];
        last unless all { $x eq $_ } @a;
        push @lca, $x;
    }
    return join('-', join('.', @lca[ 0 .. 3 ]), @lca[ 4 .. $#lca ]);
}

=head2 equiv

 Function: 
 Example : 
 Returns : true if $a and $b are the same SCOP classification, at given depth
 Args    : $id1, $id2, $depth (optional)

depth=0 => (default) true when $a eq $b
depth=1 => true for a.1.2.3 and a.2.3.4 (lca is 'a')
...
depth=4 => true for a.1.2.3-1 and a.1.2.3-2 (lca is a.1.2.3)
depth=5 => same as depth=0 ($a eq $b eq lca($a,$b))

NB equiv("a.1.2", "a.1.2", 4) will be false. Original labels only length 3

=cut

sub equiv {
    my ($a, $b, $depth) = @_;
    return $a eq $b unless $depth;
    my $lca = lca($a, $b);
    my @s = split /[.-]/, $lca;
    return defined $s[ $depth - 1 ];
}

1;

__END__


