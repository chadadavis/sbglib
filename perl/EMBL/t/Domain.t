#!/usr/bin/env perl

use Test::More 'no_plan';

use EMBL::Domain;
use EMBL::Transform;

use PDL;
use PDL::Matrix;
# use PDL::Ufunc;

my $dom = new EMBL::Domain();
isa_ok($dom, "EMBL::Domain");
isa_ok($dom->cofm, "PDL::Matrix");
is($dom->cofm, mpdl (0,0,0,1), 'Identity 3-tuple centre-of-mass, affine');
isa_ok($dom->transformation, "EMBL::Transform");
is_deeply($dom->transformation, new EMBL::Transform, 'Identity Tranform, affine');



__END__


# Get transform to superimpose 2uzeA onto 2okrA
# TODO Need to locate this script, relative to INSTALLDIR
my $transtxt = `./transform.sh 2uzeA 2okrA`;

my $pdbidchainid = shift || '2uzeC';

# Get coords
my $c = new EMBL::CofM;
$c->fetch($pdbidchainid);


print "cofm->stringify: $c\n";
print "cofm->pt: ", $c->pt;
print "cofm->dom: ", $c->dom, "\n";
print "cofm->dom2: ", $c->dom2, "\n";

__END__

# Transform 2uzeC using transformation from 2uzeA => 2okrA
# Put 2uzeC into 2okrA's frame of reference

# $c->transform($transtxt);
# $c->transform2($transtxt);

my $t = new EMBL::Transform;
$t->load($transtxt);

# $c->transform($transtxt);
$c->transform($t);

print "Transforming...\n";
print "cofm: $c\n";



exit;

my $pa = ones 2;
my $pb = ones 2;
$pb += 2;
print "poverlaps: ", overlaps($pa, $pb), "\n";

my $a = mpdl (1,1,1);

my $b = mpdl (3,3,1);

my $diff = $a - $b;
my $sqdiff = $diff ** 2;
my $sum = sumover($sqdiff->transpose);

# my $sum = sumover($sqdiff);
my $sqrt = sqrt $sum;
# print "sum:$sum";
# print "sqrt:", $sqrt->at(0), "\n";
print "moverlaps:", $sqrt->at(0), "\n";

# print "overlaps:" ,overlaps($a,$b), "\n";

sub overlaps {
    my ($a, $obj, $thresh) = @_;
    $thresh ||= 0;
    my $sqdist = sumover (($a - $obj) ** 2);
    return sqrt $sqdist;
}