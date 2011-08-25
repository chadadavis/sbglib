#!/usr/bin/env perl

=head1 NAME

B<sbglist> - Interface to L<Storable> ARRAY objects

=head1 SYNOPSIS

sbgmap <sub-name> object(s).stor more-object(s).stor


=head1 DESCRIPTION

Calls sub-name over all the objects in the given files. 

sbgmap SBG::Domain::descriptor files.stor [more-files.stor] 


=head1 OPTIONS

=head2 -h Print this help page

=head1 SEE ALSO



=cut

# Don't use strict/warnings here, as that would enforce the incoming function
# use strict;
# use warnings;
use Getopt::Long;
use Pod::Usage;

# Local libraries
use FindBin qw/$Bin/;
use lib "$Bin/../lib/";

use SBG::Role::Storable qw/retrieve_files/;
use SBG::U::List qw/flatten/;

my %ops;
my $result = GetOptions(\%ops, 'h|help',);
if ($ops{h}) { pod2usage(-exitval => 1, -verbose => 2); }

my $function = eval shift;
my @files    = @ARGV;
@files or pod2usage(-exitval => 2);
my @objs = flatten retrieve_files(@files);
my $res;

my @res = map { $function->($_) } @objs;
print join("\n", @res), "\n";

