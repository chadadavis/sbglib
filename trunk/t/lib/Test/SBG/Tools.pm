#!/usr/bin/env perl

=head1 NAME

Test::SBG::Tools - Collection of modules useful for testing

=head2 SYNOPSIS

 use Test::SBG::Tools;

=head2 DESCRIPTION

See the source for the list of modules that this module imports for you:

 pmcat Test::SBG::Tools;
    
=cut

package Test::SBG::Tools;
use strict;
use warnings;
use Moose::Autobox;
use FindBin;
use Data::Dumper;
use Test::Most;
use Test::Approx;
use File::Spec::Functions;
use Path::Class;
use File::Basename;
use File::Temp;
use Carp;

use SBG::Debug;

# These wont' be imported to the caller, just here for documentation
# of the function names
use Test::SBG::PDL qw/pdl_approx/;
use SBG::U::Object qw/load_object/;

sub import {
    strict->import;
    warnings->import;
    Moose::Autobox->import;

    Data::Dumper->export_to_level(1, qw(@Data::Dumper::EXPORT));
    Test::Most->export_to_level(1, qw(@Test::Most::EXPORT));
    Test::Approx->export_to_level(1, qw(@Test::Approx::EXPORT));
    File::Spec::Functions->export_to_level(1,
        qw(@File::Spec::Functions::EXPORT));
    Path::Class->export_to_level(1, qw(@Path::Class::EXPORT));
    File::Basename->export_to_level(1, qw(@File::Basename::EXPORT));
    File::Temp->export_to_level(1, qw(@File::Temp::EXPORT));
    Carp->export_to_level(1, qw(@Carp::EXPORT));

    # Cannot import Carp::cluck because it's from @EXPORT_OK, not @EXPORT

    # Cannot import $FindBin::Bin because it's from @EXPORT_OK, not @EXPORT
    #    FindBin->export_to_level(1, qw(@FindBin::EXPORT_OK));

    # Cannot import pdl_approx because it's from @EXPORT_OK, not @EXPORT
    #    Test::SBG::PDL->export_to_level(  1, qw(@Test::SBG::PDL::EXPORT_OK));

    # Cannot import load_object because it's from @EXPORT_OK, not @EXPORT
    #    SBG::U::Object->export_to_level(  1, qw(@SBG::U::Object::EXPORT_OK));
}

1;

