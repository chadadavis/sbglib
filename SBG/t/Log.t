#!/usr/bin/env perl

use Test::More 'no_plan';
use feature 'say';

use SBG::Log;
ok($logger);
ok($logger->debug("Debugged"));

