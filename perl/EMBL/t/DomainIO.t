#!/usr/bin/env perl

use Test::More 'no_plan';

use File::Temp qw(tempfile);

use EMBL::DomainIO;

use FindBin;
my $dir = $FindBin::RealBin;

my $io = new EMBL::DomainIO;
ok(defined $io, "new()");
isa_ok($io, "EMBL::DomainIO");

my $file = "$dir/2nn6.dom";

# Open a not-yet-opened file
my $iofile = new EMBL::DomainIO(-file=>"<$file");
ok($iofile && $iofile->fh, "new(-file=>\"<$file\")");
ok($iofile->close, "close()");

# Open an already-opened filehandle
open my $fh, "<$file";
ok($fh, "Opening <$file first");
my $iofh = new EMBL::DomainIO(-fh=>$fh);
is($iofh->fh, $fh, "Filehandle reused");
ok($iofh && $iofh->fh, "new(-fh=>\$fh)");

# Read all domains from a dom file
my @doms;
while (my $dom = $iofh->next_domain) {
    push @doms, $dom;
}
is(@doms, 9, "Read in " . scalar(@doms) . " domains");

# Write domains
my $outfile = "${file}.out";
my $ioout = new EMBL::DomainIO(-file=>">$outfile");
ok($ioout && $ioout->fh, "new(-file=>\">$outfile\")");
foreach my $d (@doms) {
    ok($ioout->write($d, -newline=>1), "Writing: " . $d->stampid);
}
system("cat $outfile");
ok(unlink($outfile), "Removing $outfile");

# Test pdbc
my $dom = pdbc(-pdbid=>'2nn6', -chainid=>'A')->next_domain();
is($dom->stampid, '2nn6a', 'pdbc');

# Domain without a file
my $stampid = '2nn6A';
my $domnofile = new EMBL::Domain(-stampid=>$stampid);
$domnofile->stampid2pdbid;
my $ghostio = new EMBL::DomainIO;
my $str = $ghostio->write($domnofile);
my $desc = $domnofile->descriptor;
# Header line must begin with whitespace when no filename (STAMP handles this)
ok($str =~ /^\s+${stampid}\s+\{\s+${desc}\s+\}\s*$/, "Output format correct");


my $tdom = new EMBL::Domain(-stampid=>'2nn6A');

# Test writing temp file, using file handle
my ($tfh1, $tpath1) = tempfile();
my $io1 = new EMBL::DomainIO(-fh=>$tfh1);
$io1->write($dom, -id=>'pdbid');
$io1->flush;
ok(-s $tpath1, "Writing to temp file handle ( $tpath1 )");

# Test writing temp file, using file handle
my ($tfh2, $tpath2) = tempfile();
my $io2 = new EMBL::DomainIO(-file=>">$tpath2");
$io2->write($dom, -id=>'stampid');
$io2->flush;
ok(-s $tpath2, "Writing to temp file handle ( $tpath2 )");


__END__
