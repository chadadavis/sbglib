#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Approx;
use IPC::Cmd qw(can_run);

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib/";

use SBG::Debug;
use SBG::Run::naccess qw/sas_atoms/;
use SBG::Domain;

plan skip_all => 'Binary not installed: naccess' unless can_run('naccess');

my $dom = SBG::Domain->new(pdbid => '1ral');
my $sas = sas_atoms($dom);

# If you get 28241.3 here, then you're erroneously using PQS
# PDB and Biounit both report one chain, for which naccess gives 15197.4
is_approx($sas, 15197.4, 'sas_atoms() (fails if using PQS)');

done_testing();

__END__

