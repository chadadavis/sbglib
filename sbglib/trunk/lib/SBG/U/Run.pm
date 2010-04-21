#!/usr/bin/env perl

=head1 NAME

SBG::U::Run

=head1 SYNOPSIS



=head1 DESCRIPTION

Utilities for executables, including file locking, logging, option processing

=head1 SEE ALSO


=cut



package SBG::U::Run;
use base qw/Exporter/;
our @EXPORT_OK = qw/start_lock end_lock start_log frac_of getoptions/;


use strict;
use warnings;

use Pod::Usage;
use Getopt::Long;

use File::NFSLock;
use Fcntl qw/LOCK_EX LOCK_NB/;
use File::Slurp qw/slurp/;

use SBG::U::Log;
use Log::Any qw/$log/;
use Log::Any::Adapter;



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
        } else {
            $log->info("$basepath already done");
        }
        return;
    }

    # Being computed by another process?
    my $lock = File::NFSLock->new($donefile,LOCK_EX|LOCK_NB);

    # Why is this necessary? Don't give me a lock, if it's not locked!
    unless (defined $lock && ! $lock->{unlocked}) {
        my $ext = $File::NFSLock::LOCK_EXTENSION;
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
    open my $fh, ">$file";
    print $fh $result, "\n" if defined $result;
    close $fh;
    $lock->unlock;
    return -e $file;
}



=head2 start_log

 Function: 
 Example : 
 Returns : 
 Args    : 

Deprecated

=cut
sub start_log {
    my ($name, %ops) = @_;
    SBG::U::Log::init($name, %ops);
    Log::Any::Adapter->set('+SBG::U::Log');
    $log->info("$0 $name " . join ' ', %ops);
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
    return $abs;
}



=head2 getoptions

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub getoptions {
    my (@ops) = @_;
    # Throw in some standard options
    # J is for the line number of a PBS job array
    # A list file contains the paths of the inputs to be processed
    # The -J option say which line (0-based) is the current input file
    # The -M option is for an email address (used by PBS, among others)
    push @ops, qw/help|h debug|d loglevel|l=s logfile|f=s logdir=s J=s M=s/;

    my %ops;
    # This makes single-char options case-sensitive
    Getopt::Long::Configure ('no_ignore_case');
    my $result = GetOptions(\%ops, @ops);
    
    if (! $result || $ops{'help'}) {
        pod2usage(-exitval=>1, -verbose=>2); 
    }

    # Running in debugger? Setup debug mode automatically
    $ops{'debug'} = 1 if defined $DB::sub;
    $SIG{__DIE__} = \&confes if $ops{'debug'};
    $ops{'loglevel'} ||= 'DEBUG' if $ops{'debug'};

    return %ops;
}



