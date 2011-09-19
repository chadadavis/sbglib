#!/usr/bin/env perl

=head1 NAME

SBG::Debug - Enable debugging for common modules

=head1 DESCRIPTION

 use SBG::Debug qw(debug);
 if (debug) { print "Debugging mode" }
 SBG::Debug->debug(1); # now it's on
 SBG::Debug->debug(0); # now it's off

A simple interface to set/unset common debugging options:

 $ENV{SBGDEBUG} = 1;          # Env. var. for SBG applications
 $Carp::Verbose = 1;          # Print stack trace on carp or cluck
 $SIG{__DIE__} ||= \&confess; # Print stack trace on die();
 $File::Temp::KEEP_ALL = 1;   # Keep any temp files
 $File::Temp::DEBUG = 1;

If run under the Perl debugger or if SBGDEBUG is defined in the environment,
this module automatically enables these debugging options.

Since this manipulates global variables from many packages, it's not
thread-safe. It enables these debugging options for every module in your
program.

=head1 TODO

Check Getopt for --debug
 
Set log level for L<SBG::Log>
    (TODO BUG but that might create a new log). 

Disable caching for L<SBG::Cache>

=cut

package SBG::Debug;
use strict;
use warnings;

use Carp qw/carp confess/;
# Will enable keeping of created temp file
use File::Temp;
# Will enable profiling of DBI statements
use DBI;

use base qw(Exporter);
our @EXPORT_OK = qw(debug);

my $_DEBUG;

# Enable by default if in a debugging environment
_set() if _check();

# Automatically enabled when run under debugger
# or when SBGDEBUG defined in environment
sub _check {
    return ($ENV{SBGDEBUG} || defined $DB::sub) ? 1 : 0;
}

=head2 debug 

Get or set C<debug()> mode

=cut

sub debug {

    # Called like a method?
    my $pkg = shift;
    my $enable = defined $pkg && $pkg eq __PACKAGE__ ? shift : $pkg;

    return $_DEBUG unless defined $enable;
    if ($enable) {
        _set();
    }
    else {
        _unset();
    }
}

sub _set {
    $_DEBUG = 1;
    $ENV{SBGDEBUG} = 1;

    # Make carp behave like cluck, and croak like confess
    $Carp::Verbose = 1;

    # Stack trace on die(), unless already set
    $SIG{__DIE__} ||= \&confess;

    # Keep temp files
    $File::Temp::KEEP_ALL = 1;
    $File::Temp::DEBUG    = 1;

    $ENV{DBI_PROFILE} = 2;
}

# Note, this doesn't restore any previous state, it just turns everything off
sub _unset {
    $_DEBUG = 0;
    delete $ENV{SBGDEBUG};
    delete $ENV{DBI_PROFILE};

    # Make carp behave like cluck, and croak like confess
    $Carp::Verbose = 0;

    # Stack trace on die()
    $SIG{__DIE__} = 'DEFAULT';

    # Keep temp files
    $File::Temp::KEEP_ALL = 0;
    $File::Temp::DEBUG    = 0;
}

1;
