#!/usr/bin/env perl

package Test::SBG;
use Test::Class;
use Exporter;
use base qw/Test::Class Exporter/;

use FindBin qw/$Bin/;
use Data::Dump qw/dump/;
use Data::Dumper qw/Dumper/;
use Test::Most;

our @EXPORT = (
    @FindBin::EXPORT,
    qw/$Bin/,
    @Data::Dump::EXPORT,
    qw/dump/,
    @Data::Dumper::EXPORT,
    qw/Dumper/,
    @Test::Most::EXPORT,
    );
    
    
INIT { Test::Class->runtests }
    

1;
