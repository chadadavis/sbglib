#!/usr/bin/env perl

=head1 NAME

Test::SBG - Base test class for SBG

=head1 SYNOPSIS

 use base 'Test::SBG';
 
 sub mytest : Tests {
     ok(1+1==2);
     ok(0!=1);
 }

=head1 DESCRIPTION

Test all the loaded classes.

Calling this in the parent allows individual classes to be tested. Preferrable
over simply calling Test::Class->runtests in a *.t script    

Note that the test methods here are inherited and run for each child class

startup() and shutdown() run once for each test class.

setup() and teardown() run once for each test in a test class.

=head1 SEE ALSO

L<Test::Class>

=head1 METHODS

=cut

package Test::SBG;
use strict;
use warnings;
use base qw/Test::Class/;

use Test::More;
use Path::Class;
use Log::Any::Adapter;

use SBG::Debug; 


INIT { 

    # Enable logging to t/tests.log 
    my $logfile = file(__FILE__)->dir->parent->parent->file('tests.log');
    Log::Any::Adapter->set('+SBG::U::Log',file=>"$logfile");
    
    Test::Class->runtests;
}


=head2 startup

Startup method for every inherited class, loads the testee() class

Note, you can override this and then refer to the parent test with:

    $self->SUPER::startup;  
=cut
sub startup : Tests(startup=>1) {
    my $self = shift;
    # Each test class is prefixed with Test::
    (my $class = ref $self) =~ s/^Test:://;
    return ok 1, "$class already loaded" if $class eq __PACKAGE__;
    use_ok $class or die;
    $self->{class} = $class;
    return $self;
}


=head2 test_data

Common directory for test data at: t/test_data

    sub some_test : Tests {
        my $self = shift;
        my $data_dir = $self->{tests_data}
        open my $fh, '<', file($data_dir, 'data_for_this_test.dat');
    }
=cut
sub _test_data : Tests(startup) {
	my $self = shift;
    my $test_data = file(__FILE__)->dir->parent->parent->subdir('test_data');
    $self->{test_data} = $test_data;
    return $self;
}

    
1;
