#!/usr/bin/env perl

use Test::More 'no_plan';
use Carp;
use FindBin qw/$Bin/;


use FindBin qw/$Bin/;
use lib "$Bin/../../../lib/";
use SBG::U::Test 'float_is';

use SBG::DomainIO::stamp;
my $file = "$Bin/../data/2nn6.dom";
my $io;


# Test reading all at once, array context
$io = new SBG::DomainIO::stamp(file=>"<$file");
my @doms = $io->read;
is(@doms, 9, "Read in " . scalar(@doms) . " domains, array context");


# Test reading one by one, scalar context
my $io2 = new SBG::DomainIO::stamp(file=>"<$file");
my @doms2;
while (my $dom2 = $io2->read) {
    push @doms2, $dom2;
}
is_deeply(\@doms2, \@doms, "Reading domains in scalar context");


# Write out a set of domains
my $out = new SBG::DomainIO::stamp(tempfile=>1);
$out->write(@doms);
$out->close;
# And read back in
my $io3 = new SBG::DomainIO::stamp(file=>$out->file);
my @doms3 = $io3->read;
is_deeply(\@doms3, \@doms, "Re-reading written domains");


# When only some domains have transformations:
my $io4 = new SBG::DomainIO::stamp(file=>"$Bin/../data/model.dom");
my @doms4= $io4->read;
my $transes = grep { $_->transformation->has_matrix } @doms4;
is($transes, 4, "Parsing domains with explicit transformations");


__END__
