#!/usr/bin/env perl

=head1 NAME

B<cyc2fasta> - Extract complexes from CYC2008 set and write Fasta files 

=head1 SYNOPSIS

cyc2fasta < cyc2008_complexes.csv

=head1 DESCRIPTION


=head1 SEE ALSO

L<Bio::DB::SGD>,

=cut 


use strict;
use warnings;

use Moose::Autobox;
use Bio::DB::SGD;
use Bio::SeqIO;
use LWP::Simple;

# Local libraries
use FindBin qw/$Bin/;
use lib "$Bin/../lib/";

use SBG::U::Run qw/getoptions start_log/;

# Read from STDIN or from a (single) file 
my $file = shift;
open *STDIN, $file if $file;

my %complexid;
# Index complex names
my $limit = 408;
for (my $complex = 1; $complex <= $limit; $complex++) {
    my $content = get "http://wodaklab.org/cyc2008/complex/show/$complex";
    my ($title) = $content =~ m|<title>(.*?) - CYC2008 - Wodak Lab</title>|;
    next if $title =~ /^Browse/;
    my ($name) = $title =~ /Complex (.*)/;
    $name =~ s|/|-|g;
    $complexid{$name} = $complex;
    print "$complex $name\n";
}

my %fhhash;

my $sgd = Bio::DB::SGD->new;
while (<>) {
    chomp;
    my ($orf, $gene, $complex) = split "\t";
    print "$orf $gene $complex\n";
    # Don't want slash in file names, rename complexes with dashes
    $complex =~ s|/|-|g;
    my $complexid = $complexid{$complex};
    unless ($complexid) {
        warn "No ID for $complex\n";
        next;
    }
    # Get cached output handle, keep it open since we're appending
    my $out = $fhhash{$complex};
    # If not yet cached, fetch it, and cache it
    $out ||= Bio::SeqIO->new(-file=>">>${complexid}.fa");
    $fhhash{$complex} ||= $out;
    my $seq = $sgd->get_Seq_by_id($orf);
    # Format sequence identifiers to use ORF
    $seq->display_id($orf);
    # Make the gene name the first word of the description
    $seq->desc($gene . ' ' . $seq->desc);    
    $out->write_seq($seq);
   
}


exit;

