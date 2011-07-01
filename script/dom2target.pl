#!/usr/bin/env perl

# NB could also use ComplexIO, but we want to create the domains with cofm

use File::Basename;

# Local libraries
use FindBin qw/$Bin/;
use lib "$Bin/../lib/";
use SBG::Model;
use SBG::Complex;
use SBG::DomainIO::stamp;
use SBG::Run::cofm qw/cofm/;

foreach my $f (@ARGV) {
    _dom2complex($f);
}

exit;

sub _dom2complex {
    my ($domfile) = @_;
    my $base = basename($domfile, '.dom');
    my $io = SBG::DomainIO::stamp->new(file=>$domfile);
    my $complex = SBG::Complex->new;
    while (my $dom = $io->read) {
        my $sphere = cofm($dom);    
        my $model = SBG::Model->new(query=>$dom, subject=>$sphere);
        $complex->set($dom, $model);
    }
    my $file = "$base.target";
    $complex->store($file);
    print "$file written\n";
}


