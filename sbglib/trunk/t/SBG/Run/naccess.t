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

done_testing();

__END__

