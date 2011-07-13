#!/usr/bin/env perl
=head1 NAME

Test::SBG::Tools - Collection of modules use for testing

=head2 SYNOPSIS

    use Test::SBG::Tools;
    
=cut


package Test::SBG::Tools;

use Moose::Autobox;
use FindBin qw/$Bin/;
use Data::Dumper qw/Dumper/;
use Test::Most;
use Test::Approx;
use File::Spec::Functions;
use Path::Class;
use File::Basename;
use File::Temp;
use Carp qw/carp cluck croak confess/;

use Test::SBG::PDL; # qw/pdl_approx/;
use SBG::U::Object qw/load_object/;

sub import {
    Moose::Autobox->import;
    FindBin->import('$Bin');
    Data::Dumper->import('Dumper');
    Test::Most->import;
    Test::Approx->import;
    File::Spect::Functions->import;
    Path::Class->import(qw/file dir/);
    File::Basename->import;
    File::Temp->import;
    Carp->import(qw/carp cluck croak confess/);
    
    Test::SBG::PDL->import(qw/pdl_approx/);    
    SBG::U::Object->import(qw/load_object/);
}


1;

