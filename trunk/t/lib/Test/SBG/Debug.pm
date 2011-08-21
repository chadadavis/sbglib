#!/usr/bin/env perl
package Test::SBG::Debug;
use base qw(Test::SBG);
use Test::SBG::Tools;


sub default : Tests  {
    local $TODO = "Test enabled by default when SBGDEBUG set";
}

sub off_on : Tests {
    local $TODO = "debug() can be turned off and on again";
}

1;
