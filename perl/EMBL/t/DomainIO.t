#!/usr/bin/env perl

use Test::More 'no_plan';

use EMBL::DomainIO;

my $io = new EMBL::DomainIO;
ok(defined $io, "new()");
isa_ok($io, "EMBL::DomainIO");

my $file = 't/2nn6.dom';

# Open a not-yet-opened file
my $iofile = new EMBL::DomainIO(-file=>"<$file");
ok($iofile && $iofile->fh, "new(-file=>\"<$file\")");
ok($iofile->close, "close()");

# Open a previously opened filehandle
open my $fh, "<$file";
ok($fh, "Opening <$file");
my $iofh = new EMBL::DomainIO(-fh=>$fh);
ok($iofh && $iofh->fh, "new(-fh=>\$fh)");

# Read all domains from a dom file
my @doms;
my $outfile = "${file}.out";
my $ioout = new EMBL::DomainIO(-file=>">$outfile");
ok($ioout && $ioout->fh, "new(-file=>\">$outfile\")");

while (my $dom = $iofh->next_domain) {
    push @doms, $dom;
}
is(@doms, 9, "Reading in all domains");

# Now test $ioout->write($dom)


__END__
