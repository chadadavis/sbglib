#!/usr/bin/env perl

package Test::SBG::U::Log;
use base qw/Test::SBG/;
use Test::SBG::Tools;

# The front end / API
use Log::Any qw/$log/;

# The adapter to the back end / plugin
use Log::Any::Adapter;

sub setting : Tests {
    my $entry = Log::Any::Adapter->set(
        '+SBG::U::Log',
        name  => 'alpha',
        level => 'warn'
    );
    local $TODO = "Setting Categories";
}

sub warnings : Test {
    local $TODO = "Use Test::Warn to capture stderr and check it";
}

1;
