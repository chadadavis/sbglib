#!/usr/bin/env perl

=head1 NAME



=head1 SYNOPSIS



=head1 DESCRIPTION


=head1 OPTIONS


=head1 SEE ALSO


=cut

################################################################################

package SBG::U::Run;
use base qw/Exporter/;
our @EXPORT_OK = qw/start_lock end_lock start_log frac_of slurp getoptions/;


use strict;
use warnings;

use Pod::Usage;
use Getopt::Long;

use File::NFSLock;
use Fcntl qw/LOCK_EX LOCK_NB/;

use SBG::U::Log;
use Log::Any qw/$log/;
use Log::Any::Adapter;


################################################################################
=head2 start_lock

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub start_lock {
    my ($basename) = @_;
    my $donefile = $basename . '.done';

    # Already finished?
    if (-e $donefile) {
        if (-s $donefile) {
            my $content = slurp($donefile);
            $log->debug("$basename already done: $content");
        } else {
            $log->debug("$basename already done");
        }
        return;
    }

    # Being computed by another process?
    my $lock = File::NFSLock->new($donefile,LOCK_EX|LOCK_NB);

    # Why is this necessary? Don't give me a lock, if it's not locked!
    unless (defined $lock && ! $lock->{unlocked}) {
        my $ext = $File::NFSLock::LOCK_EXTENSION;
        my $lockedby = slurp($donefile . $ext);
        $log->info("$basename : locked by: $lockedby");
        return;
    }

    return $lock;
}



################################################################################
=head2 end_lock

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub end_lock {
    my ($lock, $result) = @_;
    # TODO DES API break
    my $file = $lock->{file};
    open my $fh, ">$file";
    print $fh $result, "\n" if defined $result;
    close $fh;
    $lock->unlock;
    return -e $file;
}


################################################################################
=head2 start_log

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub start_log {
    my ($name, %ops) = @_;
    return unless $ops{'loglevel'};
    my $logfile = $ops{'logfile'} || $name . '.log';
    SBG::U::Log::init($ops{'loglevel'}, $logfile);
    Log::Any::Adapter->set('+SBG::U::Log');
    $log->debug("$0 $name " . join ' ', %ops);
}


################################################################################
=head2 slurp

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub slurp { 
    local( $/, @ARGV ) = ( wantarray ? $/ : undef, @_ ); 
    return <ARGV>;
}



################################################################################
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
    if ($frac =~ /^([.0-9])+\%$/) {
        $abs = $of * $1 / 100.0;
    }
    return $abs;
}


################################################################################
=head2 getoptions

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub getoptions {
    my (@ops) = @_;
    # Throw in some standard options
    push @ops, qw/help|h loglevel|l=s logfile|f=s debug|d/;

    my %ops;
    my $result = GetOptions(\%ops, @ops);
    
    if (! $result || $ops{'help'}) {
        pod2usage(-exitval=>1, -verbose=>2); 
    }

    $SIG{__DIE__} = \&confes if $ops{'debug'};
    $ops{'loglevel'} ||= 'DEBUG' if $ops{'debug'};

    return %ops;
}



