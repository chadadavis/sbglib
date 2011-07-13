#!/usr/bin/env perl

package Test::SBG::U::Log;
use base qw/Test::SBG/;
use Test::SBG;

# The front end / API
use Log::Any qw/$log/;
# The adapter to the back end / plugin
use Log::Any::Adapter;


sub basic : Tests {
    my $entry;
    Log::Any::Adapter->remove($entry);
    $entry = Log::Any::Adapter->set('+SBG::U::Log', name=>'alpha');
}


sub more : Tests {
    my $entry = Log::Any::Adapter->set('+SBG::U::Log', name=>'alpha', level=>'info');
    
    $log->error('error');
    ok(Log::Any::Adapter->set('+SBG::U::Log', name=>'beta'));
    $log->warn('warn');
    ok(Log::Any::Adapter->set('+SBG::U::Log', name=>'gamma'));
    $log->warn('warn2');
    my $ret = $log->info('info');
    is($ret, 'info', 'logging returns log message?');
    
}

sub manymoretests : Tests {

}

# test::Warn to get contents of stderr

# Test levels: warn shows but info doesn't by default
#set to info, see that info shows, but debug doesnt
#set each level to verify names: fatal, error, warn, info, debug, trace

# test that setting name appears at begin of line

# Test one line vs multi line, i,e, that remove() works

# Test contents of file

# test that file is appended, not squashed

# test relative / absolute paths to log file

# Check that PBS ID is incorporated


