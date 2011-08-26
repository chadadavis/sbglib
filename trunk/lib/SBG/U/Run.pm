#!/usr/bin/env perl

=head1 NAME

SBG::U::Run

=head1 SYNOPSIS



=head1 DESCRIPTION

Utilities for executables, including file locking, logging, option processing

=head1 SEE ALSO

=head1 TODO

Should be a Role

See also L<MooseX::Runnable>


=cut

package SBG::U::Run;
use strict;
use warnings;

use base qw/Exporter/;
our @EXPORT_OK = 
    qw/start_lock end_lock frac_of getoptions @generic_options/;

use Pod::Usage;
use Getopt::Long;
use Carp;

use File::NFSLock;
use Fcntl qw/LOCK_EX LOCK_NB/;
use File::Slurp qw/slurp/;
use File::Temp;

use SBG::U::Log;
use Log::Any qw/$log/;
use Log::Any::Adapter;

use SBG::Debug;

=head2 start_lock

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut

sub start_lock {
    my ($basepath) = @_;
    my $donefile = $basepath . '.done';

    # Already finished?
    if (-e $donefile) {
        if (-s $donefile) {
            my $content = slurp($donefile);
            $log->info("$basepath already done: $content");
        }
        else {
            $log->info("$basepath already done");
        }
        return;
    }

    # Being computed by another process?
    my $lock = File::NFSLock->new($donefile, LOCK_EX | LOCK_NB);

    # Why is this necessary? Don't give me a lock, if it's not locked!
    unless (defined $lock && !$lock->{unlocked}) {
        my $ext      = $File::NFSLock::LOCK_EXTENSION;
        my $lockfile = $donefile . $ext;
        if (-r $lockfile) {
            my $lockedby = slurp($donefile . $ext);
            $log->info("$basepath : locked by: $lockedby");
        }
        return;
    }

    return $lock;
}

=head2 end_lock

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut

sub end_lock {
    my ($lock, $result) = @_;
    return unless $lock && $lock->{file};

    # TODO DES API break
    my $file = $lock->{file};
    open my $fh, '>', $file;
    print $fh $result, "\n" if defined $result;
    close $fh;
    $lock->unlock;
    return -e $file;
}

=head2 frac_of

 Function: 
 Example : 
 Returns : 
 Args    : 

Convert percentage to literal amount.

Dont' forget to ceil() or int() the result, if you want a whole number

=cut

sub frac_of {
    my ($frac, $of) = @_;
    $of ||= 100;
    my $abs = $frac;
    if ($frac =~ /^([.0-9]+)\%$/) {
        $abs = $of * $1 / 100.0;
    }
    elsif ($frac < 1 && $frac > 0) {
        $abs = $of * $frac;
    }
    return $abs;
}

=head2 getoptions

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut

our @generic_options =
    qw/help|h debug|d=i cache|c=i loglevel|l=s logfile|f=s logdir=s/;

sub getoptions {
    my (@ops) = @_;

    # Throw in some standard options
    # J is for the line number of a PBS job array, but is also generally useful
    # A list file contains the paths of the inputs to be processed
    # The -J option says which line (0-based) is the current input file
    # The -M option is for an email address (used by PBS, among others)
    push @ops, @generic_options;

    my %ops;

    # This makes single-char options case-sensitive
    Getopt::Long::Configure('no_ignore_case');
    my $result = GetOptions(\%ops, @ops);

    if (!$result || $ops{help}) {
        pod2usage(-exitval => 1, -verbose => 2, -noperldoc => 1);
    }

    SBG::Debug->debug($ops{debug});

    return %ops;
}

