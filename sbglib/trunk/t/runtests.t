#!/usr/bin/env perl

# Where is this file: .../t
use FindBin qw/$Bin/;

# Load all *.pm test classes under ../t/*
use Test::Class::Load $Bin;

# Run all tests in all loaded subclasses of Test::Class
#Test::Class->runtests();
