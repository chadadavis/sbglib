#!/usr/bin/env perl

=head1 NAME

Test::SBG - Base test class for SBG

=head1 SYNOPSIS

 use base 'Test::SBG';
 Test::SBG->import;
 
 sub mytest : Tests {
     ok(1+1==2);
     ok(0!=1);
 }

=head1 DESCRIPTION

Provides functions from many test modules.

startup() and shutdown() run once for each test class.

setup() and teardown() run once for each test in a test class.

=head1 SEE ALSO

L<Test::Class>

=cut

package Test::SBG;
use strict;
use warnings;
use base qw/Test::Class Exporter/;


use FindBin qw/$Bin/;
use Data::Dumper qw/Dumper/;
use Test::Most;
use Test::Approx;
use File::Spec::Functions;
use Path::Class;
use File::Basename;
use File::Temp;
$File::Temp::KEEP_ALL = $DB::sub;

use SBG::U::Run qw/start_log/;
use SBG::U::Test qw/pdl_approx/;

# Re-export everything needed for testing
our @EXPORT = (
    @FindBin::EXPORT,
    qw/$Bin/,
    @Data::Dump::EXPORT,
    qw/dump/,
    @Data::Dumper::EXPORT,
    qw/Dumper/,
    @Test::Most::EXPORT,
    @Test::Approx::EXPORT,
    @File::Spec::Functions::EXPORT,
    @Path::Class::EXPORT,
    @File::Basename::EXPORT,
    @File::Temp::EXPORT,
    qw/pdl_approx/,
    );

our $DEBUG = $DB::sub;
$File::Temp::KEEP_ALL = $DEBUG;


# Test all the loaded classes
# Calling this in the parent allows individual classes to be tested
# Preferred over simply calling Test::Class->runtests in a *.t script    
INIT { 

    # Start logging 
    my $logfile = file(__FILE__)->dir->parent->file('test.log');
    start_log('test', loglevel=>'DEBUG', logfile=>$logfile);

    Test::Class->runtests;
}


# Note that the test methods here are inherited and run for each child class


# Startup method for every inherited class, loads the testee() class
# Note, you can override this and then refer to the parent test with:
#  $self->SUPER::startup;  
sub startup : Tests(startup=>1) {
    my $self = shift;
    # Each test class is prefixed with Test::
    (my $class = ref $self) =~ s/^Test:://;
    return ok 1, "$class already loaded" if $class eq __PACKAGE__;
    use_ok $class or die;
    $self->{class} = $class;
    return $self;
}


# Make sure that each test object knows where to get test data from
sub test_data : Tests(startup) {
	my $self = shift;
    my $test_data = file(__FILE__)->dir->parent->parent->subdir('test_data');
    $self->{test_data} = $test_data;
    return $self;
}

    
1;
