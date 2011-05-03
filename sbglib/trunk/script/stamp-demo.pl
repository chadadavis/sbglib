#!/usr/bin/env perl
use strict;
use FindBin qw/$Bin/;
use lib "$Bin/../lib/";

use SBG::STAMP qw/superposition/;
use SBG::Domain;

# Default options: 
#         "-s",               # scan mode: only query compared to each DB sequence
#         "-secscreen F",     # Do not perform initial secondary structure screen
#         "-opd",             # one-per-domain: just one hit per query domain
#         "-n $nfit",         # $SBG::STAMP::nfit = 2
#         "-slide $slide",    # $SBG::STAMP::slide = 5 
#         "-minfit $minfit",  # $SBG::STAMP::minfit = 30
#         "-scancut $scancut",#$SBG::STAMP::scancut = 2.0
# To change them:
# $SBG::STAMP::prameters = "-s -n 3 -scancut 3";

my $domfile = shift or die;
use SBG::DomainIO::stamp;
my $input = SBG::DomainIO::stamp->new(file=>$domfile);

# index the starting position of each object in the file, to avoid loading all
my $index = $input->index;

# Get the ith domain (numbered from 0)
sub _domi { 
    my $i = shift;
    my $pos = $input->index->[$i];
    $input->seek($pos);
    return $input->read;
}

# If you don't need indexing, if you have enough memory, you can also do:
#my @doms;
#while (my $dom = $input->read) {
#    push @doms, $dom;
#}
# And then just access $doms[$i] later
    
# All pairs
for (my $i = 0; $i < @$index; $i++) {
    my $domi = _domi($i);
    
    for (my $j = $i + 1; $j < @$index; $j++) {
        my $domj = _domi($j);
        
            # This is always the transformation from i onto j (j is fixed)
            my $super = superposition($domi, $domj);
            # If you want the inverse, it's;
            # print $super->transformation->inverse;
            
            # If you also want to apply the transformation permanently
            # $super->transformation->apply($domi);
            # And then print a STAMP-formatted DOM file with SBG::DomainIO::stamp
            
            # See SBG::Superposition for details of the score names
            # E.g. 'RMS', 'Sc', ...
            print "Score: RMS", $super->scores->{'RMS'}, ' Sc:', $super->scores->{'Sc'}, "\n";
            # Or do your own thing
            my %scores = %{$super->scores};
            
            # Prints the matrix, which is in $super->transformation
            # It's an instance of SBG::TransformationI
            # The raw matrix (a PDL) would be: $super->transformation->matrix
#            print $super, "\n";          
            
            # if you want it in block-formatted text with newlines (no headers)
            use SBG::TransformIO::stamp;
            my $string;
            my $io = SBG::TransformIO::stamp->new(string=>\$string);
            $io->write($super->transformation);
            print $string; 
    }
}    