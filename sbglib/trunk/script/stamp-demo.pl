#!/usr/bin/env perl
use strict;
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

# Example:
my $data = [
    { pdbid=>'1tim', descriptor=>'CHAIN A' },
    { pdbid=>'1tim', descriptor=>'CHAIN B' },
    { pdbid=>'1dkw', descriptor=>'CHAIN A' },
    { pdbid=>'1dkw', descriptor=>'CHAIN B' },
    # ...
    ];
    
    
# All pairs
for (my $i = 0; $i < @$data; $i++) {
    my $domi = SBG::Domain->new(
        pdbid=>$data->[$i]->{pdbid}, descriptor=>$data->[$i]->{descriptor});
    
    for (my $j = $i + 1; $j < @$data; $j++) {
        my $domj = SBG::Domain->new(
            pdbid=>$data->[$j]->{pdbid}, descriptor=>$data->[$j]->{descriptor});
        
            # This is always the transformation from i onto j (j is fixed)
            my $super = superposition($domi, $domj);
            # If you want the inverse, it's;
            # print $super->transformation->inverse;
            
            # If you also want to apply the transformation permanently
            # $super->transformation->apply($domi);
            # And then print a STAMP-formatted DOM file with SBG::DomainIO::stamp
            
            # See SBG::Superposition for details of the score names
            # E.g. 'RMS', 'Sc', ...
            print $super->scores('RMS'), ' ', $super->scores('Sc');
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