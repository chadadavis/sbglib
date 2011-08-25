#!/usr/bin/env perl

=head1 NAME

B<sbgsplitdom> - 

=head1 SYNOPSIS

sbgsplitdom < fasta1.fa  > fastasplit.fa

=head1 DESCRIPTION


=head1 OPTIONS

=head2 -h|elp Print this help page

=head2 -l|og Set logging level


=head1 SEE ALSO

L<SBG::SplitI>,

=cut 

use strict;
use warnings;

use Moose::Autobox;
use Bio::SeqIO;

# Local libraries
use FindBin qw/$Bin/;
use lib "$Bin/../lib/";

use SBG::U::Run qw/getoptions/;
use SBG::Split::3DR;

# Read from STDIN or from a (single) file
my $file = shift;
open *STDIN, $file if $file;

my %ops = getoptions qw/mingap|g=i/;
$ops{mingap} = 30 unless defined $ops{mingap};
my $in = Bio::SeqIO->new(-fh => \*STDIN);
my $out = Bio::SeqIO->new(-fh => \*STDOUT, -format => 'fasta');
my $splitter = SBG::Split::3DR->new(mingap => $ops{mingap});

while (my $seq = $in->next_seq) {
    my $subseqs = $splitter->split($seq);
    $out->write_seq($_) for @$subseqs;
}

exit;

