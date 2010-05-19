#!/usr/bin/env perl

=head1 NAME

SBG::U::Log - Logging setup

=head1 SYNOPSIS

 use SBG::U::Log qw/log/;
 # Without any initialisation, WARN and ERROR go to STDERR, others ignored
 log()->debug("x is: $x"); # not printed anywhere
 log()->error("cannot open: $file)"; # printed to STDERR

 # initialize logging. Default level is 'WARN', default file is './log.log'
 log()->init(loglevel=>'DEBUG', logfile=>'/tmp/somewhere.log');
 log()->debug("x is: $x"); # Appended to /tmp/somewhere.log
 log()->error("bad things"); # Saved to logfile, but no longer to STDERR

=head1 DESCRIPTION

By default there is no logging. WARN and ERROR messages will just go to
STDERR. 

When logging, WARN and ERROR and any other applicable messages all go to the log
file.

For a given level, all messages of higher severity are also logged. The list:

 TRACE DEBUG INFO WARN ERROR FATAL

The functions are defined as:

 trace debug info warn error fatal

The overlap with L<Log::Any> would be:

 debug info warn error

Sticking to these four will provide more portable code.

E.g. when set to ERROR, only ERROR and FATAL get logged. When set to DEBUG,
everything but TRACE gets logged. 

NB There is negligible penalty for using the logging system when logging
messages are not printed. I.e. logging slows down an application. But logging
does not have to be completely avoided or turned off to increase speed. Simply
set the log level to e.g. B<ERROR> to only log errors.


=head1 SEE ALSO

L<Log::Log4perl> , L<Log::Any>

=cut



package SBG::U::Log;

use base qw/Exporter/;
our @EXPORT_OK = qw(log);

use Log::Log4perl qw(:levels);
use Log::Any qw/$log/;
use Log::Any::Adapter;
use File::Spec::Functions;



=head2 logger

 Function: 
 Example : 
 Returns : 
 Args    : 

No logging by default

WARN and ERRROR messages to STDERR, others ignored

=cut
sub log {
    our $logger;
    $logger ||= bless {}, "SBG::U::LogNull";
    return $logger;
}



=head2 new

 Function: 
 Example : 
 Returns : 
 Args    : 

Alias to L<log()>

Added for compatability with L<Log::Any::Adapter>

=cut
sub new {
    my ($self) = @_;
    return $self->log();
}



=head2 init

 Function: 
 Example : 
 Returns : 
 Args    : 

This will initialize the actual file logging

In order of increasing severity: $TRACE $DEBUG $INFO $WARN $ERROR $FATAL

=cut
sub init {
    my ($name, %ops) = @_;
    my $level = $ops{'loglevel'} || 'WARN';
    $level = uc $level;
    my $logfile = $ops{'logfile'} || ($name || 'log') . '.log';
    my $logpath = File::Spec->rel2abs($logfile, $ops{'logdir'}) ;


    # Initialize system logger
    our $logger;
    $logger = Log::Log4perl->get_logger("sbg");

    # Default logging level 
    $logger->level(eval '$' . $level);
    
    # Log appenders (i.e. where the logs get sent)
    my $appendertype = ("$logfile" eq '-') ? 
        'Log::Log4perl::Appender::Screen' : 'Log::Dispatch::File';
    my $appender = Log::Log4perl::Appender->
        new($appendertype, filename => $logpath, mode => "append");

    my $h = `hostname --short`;
    chomp $h;
    $h = sprintf "%-15s", $h;
    $name = sprintf "%6s", ($name || '');
    $pbs_jobid = sprintf "%8s", ($ENV{PBS_JOBID} || 'NOTPBS');
    # Strip off any hostname
    $pbs_jobid =~ s/\..*$//;

    # Define log format for appender
    # $h host, %d date %M method %m message %n newline
    my $layout = Log::Log4perl::Layout::PatternLayout->new(
        "$name $h $pbs_jobid %d{yyyy-MM-dd HH:mm:ss} %-50M %m%n");
    # Set the layout of the appender
    $appender->layout($layout);
    # Register the appender with the logger
    $logger->add_appender($appender);

    # Send Log::Any log messages to us
    Log::Any::Adapter->set('+SBG::U::Log');
    # Log what you ran
    $log->info("$0 $name " . join ' ', %ops);

    return $logger;
}



1;


package SBG::U::LogNull;

use Carp qw/carp cluck/;

sub init {
    my $self = shift;
    return SBG::U::Log::init(@_);
}

# warn/error/fatal messages diverted to STDERR (with stack trace)

sub warn {
    my $self = shift;
    carp "@_\n";
}
*logwarn = \&warn;

sub error {
    my $self = shift;
    cluck "@_\n";
}
*error_warn = \&error;
*fatal = \&error;

# Other messages (e.g. $DEBUG, etc) just get ignored

sub debug {1;}
*trace = \&debug;
*info = \&debug;



1;

