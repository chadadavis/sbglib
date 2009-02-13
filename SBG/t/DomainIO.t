#!/usr/bin/env perl

use Test::More 'no_plan';

use File::Temp qw(tempfile);

use SBG::DomainIO;

use FindBin;
my $dir = $FindBin::RealBin;
my $file = "$dir/2nn6.dom";


# Read all domains from a dom file
open my $fh, "<$file";
my $iofh = new SBG::DomainIO(fh=>$fh);
my @doms;
while (my $dom = $iofh->read) {
    push @doms, $dom;
}
is(@doms, 9, "Read in " . scalar(@doms) . " domains");

# Write domains
my $outfile = "${file}.out";
my $ioout = new SBG::DomainIO(file=>">$outfile");
ok($ioout && $ioout->fh, "new(file=>\">$outfile\")");
foreach my $d (@doms) {
    ok($ioout->write($d), "Writing: $d");
}
system("cat $outfile");
ok(unlink($outfile), "Removing $outfile");


# Domain without a file
my $label = '2nn6A';
my ($pdbid, $chainid) = $label =~ /$pdb41/;
use SBG::Types qw/$pdb41 $re_descriptor/;
my $domnofile = new SBG::Domain(pdbid=>$pdbid,descriptor=>"CHAIN $chainid");
my $str = $domnofile->asstamp;
my $desc = $domnofile->descriptor;
# Header line must begin with whitespace when no filename (STAMP handles this)
like($str, qr/^ ${label}(.*?) \{ ${desc} \}$/, "Output format correct");


use SBG::Domain::CofM;
my $iomixed = new SBG::DomainIO(file=>"$dir/model.dom", type=>'SBG::Domain::CofM');
my @transes;
while (my $dom = $iomixed->read) {
    push @transes, $dom->transformation if $dom->transformation;
}
is(4, @transes, "4/6 Domains have explicit transformation");


__END__
