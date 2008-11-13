#!/usr/bin/env perl

use strict;
use warnings;

use lib "..";
use EMBL::CofM;
use EMBL::Transform;

use PDL;
use PDL::Matrix;
use PDL::Ufunc;

# my $a = mpdl (0,0,0,1);
# $a->slice('0,0:2') .= mpdl (1,2,3);
# print "a:$a";


# Get transform to superimpose 2uzeA onto 2okrA
# TODO Need to locate this script, relative to INSTALLDIR
my $transtxt = `./transform.sh 2uzeA 2okrA`;

# Get coords of 2uzeC
my $c = new EMBL::CofM;
$c->fetch('2uzeC');


print "cofm: $c\n";
print $c->id;
print $c->description;
print $c->file;
print $c->pt;
print "\n", $c->dom, "\n";

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
