#!/usr/bin/env perl

use Test::More 'no_plan';

use File::Temp qw(tempfile);

use SBG::DomainIO;

use FindBin;
my $dir = $FindBin::RealBin;
my $file = "$dir/2nn6.dom";


# TODO test _read_trans

# Read all domains from a dom file
open my $fh, "<$file";
my $iofh = new SBG::DomainIO(-fh=>$fh);
my @doms;
while (my $dom = $iofh->read) {
    push @doms, $dom;
}
is(@doms, 9, "Read in " . scalar(@doms) . " domains");

# Write domains
my $outfile = "${file}.out";
my $ioout = new SBG::DomainIO(-file=>">$outfile");
ok($ioout && $ioout->fh, "new(-file=>\">$outfile\")");
foreach my $d (@doms) {
    ok($ioout->write($d), "Writing: $d");
}
system("cat $outfile");
ok(unlink($outfile), "Removing $outfile");


# Domain without a file
my $label = '2nn6A';
my $domnofile = new SBG::Domain(-label=>$label);
my $ghostio = new SBG::DomainIO;
my $str = $ghostio->write($domnofile);
my $desc = $domnofile->descriptor;
# Header line must begin with whitespace when no filename (STAMP handles this)
ok($str =~ /^\s+${label}\s+\{\s+${desc}\s+\}\s*$/, "Output format correct");


__END__
