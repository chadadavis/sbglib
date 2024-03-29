#!/usr/bin/env perl

=head1 NAME

B<sbgreduce> - Interface to cached objects 

=head1 SYNOPSIS

sbgreduce CODE object(s).stor more-object(s).stor


=head1 DESCRIPTION

Read the objects saved in the given files and reduces them to a single scalar
using the code block given.

B<BLOCK> is any code block, e.g. this sums over the B<val> field of objects

sbgreduce '{ $a->val + $b->val }' file1.stor another-file.stor ...

The variables $a and $b are defined for each pair of elements in the list. The
result of the BLOCK is saved in $a in the next iteration.

Put the BLOCK in quotes to prevent your shell from interpreting it.


=head1 OPTIONS

=head2 -h Print this help page

=cut

use strict;
use warnings;

# CPAN
use Getopt::Long;
use Pod::Usage;
use List::Util qw/reduce/;

# Local libraries
use FindBin qw/$Bin/;
use lib "$Bin/../lib/";

use SBG::Role::Storable qw(retrieve_files);

my %ops;
my $result = GetOptions(\%ops, 'h|help',);
if ($ops{h}) { pod2usage(-exitval => 1, -verbose => 2); }

my $block = shift @ARGV;
@ARGV or pod2usage(-exitval => 2);
my @objs = retrieve_files(@ARGV);
my $res = reduce { eval $block } @objs;
print $res, "\n";

