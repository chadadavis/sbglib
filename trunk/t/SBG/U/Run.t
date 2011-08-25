#!/usr/bin/env perl

use strict;
use warnings;
use Test::More 'no_plan';

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib/";
use Test::Approx;
use SBG::U::Log qw/log/;

use SBG::Debug;

use SBG::U::Run qw/start_lock end_lock frac_of getoptions/;
use File::Slurp qw/slurp/;

my $lock = start_lock('lockname');
ok($lock, "Job locking");

# This should not succeed yet
my $unlocked = start_lock('lockname');
ok(!$unlocked, "Job already locked");

end_lock($lock);
ok(-e 'lockname.done', "lockname.done exists");

# No it should successed
my $lock2 = start_lock('lockname');
ok(!$lock2, "Other process completed job");
unlink 'lockname.done';

my $lock3 = start_lock('lockname');
ok($lock3, "Redoing lock");

my $percent = '52%';
my $total   = 33;
is_approx(frac_of($percent, $total), 17.16, 'frac_of')
