#!/usr/bin/env perl

=head1 NAME

B<runtests.t> - Run all tests using L<Test::Class>

=head1 SYNOPSIS

# Run all tests in all loaded subclasses of Test::Class
# This requires that all of the classes to be tested be loaded first

 Test::Class->runtests();

# Alternatively, automatically load all classes in a directory 
# Load all *.pm test classes under ../t/*

 use Test::Class::Load $Bin;

# To test a single class, use, e.g. : 

 perl -e exit -MTest::SBG::Domain

# Or just run the module:

 perl t/Test/SBG/Domain.pm
 
# which will work as long as there is a block in the root class with:

 INIT { Test::Class->runtests }

# You can also define the the TEST_METHOD env variable

 TEST_METHOD='.*_database' prove -v t/runtests.t
 
# Which will run all the method names that match /.*_database/


=head1 SEE ALSO

L<Test::Class> , L<Test::Class::Load>

=cut

# Where is this file: ../t
use FindBin qw/$Bin/;

# Alternatively, automatically load all classes in a directory 
# Load all *.pm test classes under ../t/*
use Test::Class::Load $Bin;

# Prefer to call this from the INIT {} block of the root class Test::SBG
#Test::Class->runtests();


