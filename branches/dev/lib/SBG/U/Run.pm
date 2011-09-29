#!/usr/bin/env perl

=head1 SYNOPSIS

 use SBG::U::Run qw/getoptions/;

 my %ops = getoptions();
 
 # Everything else is left in @ARGV
 for my $file (@ARGV) { 
     my $result = $ops{debug} ? method_with_debuggin() : default_method();
 }


=head1 DESCRIPTION

Utilities for executables, including file locking, logging, option processing.

Default options that are parsed: (using L<Getopt::Long> syntax)

 help|h debug|d=i cache|c=i loglevel|l=s logfile|f=s logdir=s

=head1 SEE ALSO

=over 4

=item * L<Getopt::Long>

=item * L<MooseX::Runnable>

=back

=head1 TODO

Should be a Role, e.g. L<MooseX::Runnable>

=cut

package SBG::U::Run;
use strict;
use warnings;

use base qw/Exporter/;
our @EXPORT_OK = 
    qw/start_lock end_lock frac_of getoptions @generic_options/;

use SBG::Debug;

use Pod::Usage;
use Getopt::Long;
use Carp;

use File::NFSLock;
use Fcntl qw/LOCK_EX LOCK_NB/;
use File::Slurp qw/slurp/;

use SBG::U::Log;
use Log::Any qw/$log/;
use Log::Any::Adapter;

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


our @generic_options =
    qw/help|h debug|d=i cache|c=i loglevel|l=s logfile|f=s logdir=s/;

=head2 getoptions

Gets default options out of C<@ARGV> 

Note, this will modify your C<@ARGV>

=cut

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

