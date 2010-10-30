#!/usr/bin/env perl

=head1 NAME

Test::SBG - Base test class for SBG

=head1 SYNOPSIS


=head1 DESCRIPTION

startup() and shutdown() run once for each test class.

setup() and teardown() run once for each test in a test class.

=head1 SEE ALSO

L<Test::Class>

=cut

package Test::SBG;
use Test::Class;
use Exporter;
use base qw/Test::Class Exporter/;

use FindBin qw/$Bin/;
use Data::Dump qw/dump/;
use Data::Dumper qw/Dumper/;
use Test::Most;
use File::Spec::Functions;

our $test_data = catfile($Bin, 'test_data');

our @EXPORT = (
    qw/$test_data/,
    @FindBin::EXPORT,
    qw/$Bin/,
    @Data::Dump::EXPORT,
    qw/dump/,
    @Data::Dumper::EXPORT,
    qw/Dumper/,
    @Test::Most::EXPORT,
    @File::Spec::Functions::EXPORT,
    );
    
    
INIT { Test::Class->runtests }
    
1;
