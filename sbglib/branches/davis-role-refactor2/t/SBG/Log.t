#!/usr/bin/env perl

use Test::More 'no_plan';

use SBG::U::Log qw/log/;

ok(log()->warn("Testing warn()"));
ok(log()->error("Testing error()"));
ok(log()->debug("Testing debug()"));
my $file = './log.log';
log()->init('WARN', $file);
ok(log()->warn("Testing warn() in log file"));
ok(-s $file, "Log file $file written");
unlink $file;

