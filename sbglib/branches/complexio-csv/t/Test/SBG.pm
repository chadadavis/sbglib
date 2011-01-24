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
use File::Basename;
use File::Temp;

use SBG::U::Run qw/start_log/;

# Re-export everything needed for testing
our @EXPORT = (
    @FindBin::EXPORT,
    qw/$Bin/,
    @Data::Dump::EXPORT,
    qw/dump/,
    @Data::Dumper::EXPORT,
    qw/Dumper/,
    @Test::Most::EXPORT,
    @File::Spec::Functions::EXPORT,
    @File::Basename::EXPORT,
    @File::Temp::EXPORT,
    );


our $DEBUG = $DB::sub;
$File::Temp::KEEP_ALL = $DEBUG;


# Test all the loaded classes
# Calling this in the parent allows individual classes to be tested
# Preferred over simply calling Test::Class->runtests in a *.t script    
INIT { 

    # Start logging 
    my $logfile = catfile(dirname(__FILE__), '..', 'test.log');
    start_log('test', loglevel=>'DEBUG', logfile=>$logfile);

    Test::Class->runtests;
}


# Note that the test methods here are inherited and run for each child class


# Startup method for every inherited class, loads the testee() class
# Note, you can override this and then refer to the parent test with:
#  $test->SUPER::startup;  
sub startup : Tests(startup=>1) {
    my $self = shift;
    # Each test class is prefixed with Test::
    (my $class = ref $self) =~ s/^Test:://;
    return ok 1, "$class already loaded" if $class eq __PACKAGE__;
    use_ok $class or die;
    $self->{class} = $class;
}


# Make sure that each test object knows where to get test data from
sub test_data : Tests(startup=>1) {
	my $self = shift;
    my $test_data = catfile(dirname(__FILE__), '..', 'test_data');
    ok(-d $test_data, "test_data dir exists") or die;
    $self->{test_data} = $test_data;
}


    
    
1;