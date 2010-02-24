#!/usr/bin/env perl

use strict;
use warnings;
use Test::More 'no_plan';
use SBG::U::Test 'float_is';
use Carp;
$SIG{__DIE__} = \&confess;
use Data::Dumper;
use Data::Dump qw/dump/;
use File::Temp qw/tempfile/;

use Moose::Autobox;

use SBG::U::Log qw/log/;
my $DEBUG;
# $DEBUG = 1;
SBG::U::Log::init(undef, loglevel=>'DEBUG') if $DEBUG;

use SBG::Split::Roberto;

my $splitter = SBG::Split::Roberto->new;

my @boundaries;
@boundaries = $splitter->_smooth(100, 45, 65);
is_deeply(\@boundaries, [qw/1 55 100/], "One boundary");

@boundaries = $splitter->_smooth(110, 25, 45, 65);
is_deeply(\@boundaries, [qw/1 35 65 110/], "Two boundaries");

@boundaries = $splitter->_smooth(90, 25, 45, 65);
is_deeply(\@boundaries, [qw/1 35 90/], "Two boundaries, no end");

@boundaries = $splitter->_smooth(90, 20, 30, 65);
is_deeply(\@boundaries, [qw/1 90/], "Two boundaries, both squashed");




