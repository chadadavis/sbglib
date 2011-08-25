#!/usr/bin/env perl
package Test::SBG::Domain;
use base qw/Test::SBG/;
use Test::SBG::Tools;

sub basic : Tests {
    local $TODO = 'todo';
}

1;
