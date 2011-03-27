#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Carp;

use FindBin;
use File::Temp qw/tempfile/;


use FindBin qw/$Bin/;
use lib "$Bin/../../../lib/";

use SBG::U::Test qw/float_is pdl_approx/;
use SBG::U::Log;

use PDL;
use SBG::TransformIO::smtry;
use SBG::Transform::Affine;

# Tolerate rounding differences between clib (STAMP) and PDL
use PDL::Ufunc;
use PDL::Core;
my $toler = '1%';

my $io = SBG::TransformIO::smtry->new(file=>"$Bin/../data/pdb2nn6.ent");
my @transformations;
my $ntrans = 0;
while (my $trans = $io->read) {
	$ntrans++;
	push @transformations, $trans;
}
is($ntrans, 24, 'TransformIO::smtry->read');


my $trans_exp = pdl  
    [ 0,  0, -1,  0],
    [ 0, -1,  0,  0],
    [-1,  0,  0,  0],
    [ 0,  0,  0,  1],
    ; 
# NB @transformations contains instances of SBG::TransformationI
# $trans_exp is a PDL
pdl_approx($transformations[23]->{PDL}, $trans_exp, 
    'TransformIO::smtry->read', $toler);


done_testing();
