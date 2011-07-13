#!/usr/bin/env perl
=head1 NAME

SBG::Debug - common debug settings

=head1 DESCRIPTION

Since this manipulates global variables from many packages, it's not thread-safe

=head1 TODO
 
# Set log level (TODO BUG but that might create a new log)
# Disable caching
# Check Getopt for --debug
# Allow SBG::Debug->debug(0) to disable it, after it's been turned on

=cut

package SBG::Debug;
use strict;
use warnings;

use Carp qw/carp confess/;
use File::Temp; 

my $DEBUG;

_set() if _check();

sub debug {
    my ($enable) = @_;
    return $DEBUG unless defined $enable;
    if ($enable) { _set() } else { _unset() }
}

sub _check {
    return ($ENV{'DEBUG'} || defined $DB::sub) ? 1 : 0;  
}

sub _set {
    $DEBUG = 1;
    $ENV{DEBUG} ||= 1;
    # Make carp behave like cluck, and croak like confess
    $Carp::Verbose = 1;
    $SIG{__DIE__} ||= \&confess;
    # Increase recursion
    $DB::deep = 1000 if $DB::deep == 100; # override only if still default
    # Keep temp files
    $File::Temp::KEEP_ALL = 1;
    $File::Temp::DEBUG = 1;
}

sub _unset {
    carp 'Disabling debug is not yet implemented';
}


1;