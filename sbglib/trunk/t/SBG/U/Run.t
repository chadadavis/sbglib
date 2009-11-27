#!/usr/bin/env perl

use strict;
use warnings;
use Test::More 'no_plan';
use Data::Dump qw/dump/;

use SBG::U::Log qw/log/;

my $DEBUG;
$DEBUG = 1;
log()->init('TRACE') if $DEBUG;

use SBG::U::Run qw/start_lock end_lock start_log frac_of slurp getoptions/;

my $lock = start_lock('lockname');
ok($lock, "Job locking");
# This should not succeed yet
my $unlocked = start_lock('lockname');
ok(! $unlocked, "Job already locked");

end_lock($lock);
ok(-e 'lockname.done', "lockname.done exists");

# No it should successed
my $lock2 = start_lock('lockname');
ok(! $lock2, "Other process completed job");
unlink 'lockname.done';

my $lock3 = start_lock('lockname');
ok($lock3, "Redoing lock");

