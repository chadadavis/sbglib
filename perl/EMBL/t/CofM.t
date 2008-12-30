#!/usr/bin/env perl

use Test::More 'no_plan';

use EMBL::CofM;
use EMBL::Domain;

use PDL;
use PDL::Matrix;

my ($x, $y, $z, $rg, $file, $desc);

#NB the numerical coparisons below are not at al reliable. Better way?

# query()
my @a = EMBL::CofM::query('2nn6', 'A');
ok(@a, "EMBL::CofM::query('2nn6', 'A')");
($x, $y, $z, $rg, $file, $desc) = @a;
ok($x >= 80.860  && $x < 80.862,  'x ~ 80.861');
ok($y >= 12.450  && $y < 12.452,  'y ~ 12.451');
ok($z >= 122.080 && $z < 122.081, 'z ~ 122.080');
ok($rg >= 26.738 && $rg < 26.740, "radius of gyration (rg) ~ 26.739");
is($desc, "CHAIN A", "CofM::query descriptor: CHAIN A");
ok($file, "CofM::query file set");
print "\tfile: $file\n";

# run()
my $dom = new EMBL::Domain(-stampid=>'2nn6A');
my @b = EMBL::CofM::run($dom);
($x, $y, $z, $rg, $file, $desc) = @b;
ok($x >= 80.860  && $x < 80.862,  'x ~ 80.861');
ok($y >= 12.450  && $y < 12.452,  'y ~ 12.451');
ok($z >= 122.080 && $z < 122.081, 'z ~ 122.080');
ok($rg >= 26.738 && $rg < 26.740, "radius of gyration (rg) ~ 26.739");
is($desc, "CHAIN A", "CofM::query descriptor: CHAIN A");
ok($file, "CofM::query file set");
print "\tfile: $file\n";

# get_cofm()
my $dom2 = new EMBL::Domain(-stampid=>'2nn6A');
get_cofm($dom2);
ok(defined($dom2->cofm), "get_cofm cofm");
ok($dom2->rg, "get_cofm rg");
is($dom2->descriptor, "CHAIN A", "get_cofm descriptor: CHAIN A");
ok($file, "get_cofm file");
print "\tfile: $file\n";



__END__


