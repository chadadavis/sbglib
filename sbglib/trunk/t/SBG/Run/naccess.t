#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Data::Dumper;
use Data::Dump qw/dump/;

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib/";
use SBG::U::Test qw/float_is pdl_approx/;
use SBG::U::Log;

my $DEBUG;
$DEBUG = 1;
SBG::U::Log::init( undef, loglevel => 'DEBUG' ) if $DEBUG;

use SBG::Run::naccess qw/sas_atoms/;
use SBG::Domain;


my $dom = SBG::Domain->new(pdbid=>'1ral');
my $sas = sas_atoms($dom);
float_is($sas, 15197.4, 'sas_atoms()');

__END__

my $file = "$Bin/../data/docking2.pdb"

# Without a PDB ID;
$input = SBG::Domain->new(file=>"$Bin/../data/docking2.pdb", descriptor=>'CHAIN A');
_test($input, 17.094, (-1.106,    3.405,    1.805));

# Another docking result
$input = SBG::Domain->new(file=>"$Bin/../data/P29295.1-P41819.1-complex.2", descriptor=>'CHAIN A');
_test($input, 19.636, (40.593,    9.387,   82.034));

# Original stamp limited to 100-char filenames, check that
$input = SBG::Domain->new(file=>"$Bin/../data/loooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooong.pdb", descriptor=>'CHAIN A');
_test($input, 19.636, (40.593,    9.387,   82.034));

# With Insertion codes
$TODO = "test insertion codes";
ok 0;


done_testing();
