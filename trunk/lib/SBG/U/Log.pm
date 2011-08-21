#!/usr/bin/env perl

=head1 NAME

SBG::U::Log - Simple logging setup for Russell group

=head1 SYNOPSIS

 # In your modules, use the logger, without worrying about where the messages go
 use Log::Any '$log';
 $log->warn("might be something bad");
 $log->error("definitely something bad") and die;
 $log->debug("this won't be logged by default, you can put them everywhere");
 
 # In your scripts, define where the messages go
 # By default error and warn messages go to stderr. Other messages ignored
 use Log::Any::Adapter; 
 Log::Any::Adapter->set('+SBG::U::Log')
 
 # Or log to a file (in the current directory), and set the level to debug
 # This captures debug, info, warn, error and fatal messages. trace is ignored
 Log::Any::Adapter->set('+SBG::U::Log',level=>'debug',file=>'myapp.log') 
  
=head1 DESCRIPTION

The levels you use are up to you; you probably don't need all of them. The 
following are the most common.

=head2 LEVELS

There are many different log levels. Normally only a few are necessary:

=over 

=item debug : for reporting on details, eg. the values of variables, objects, etc
 
    $log->debug("Before x is $x");
    some_function_that_shouldnt_change_x();
    $log->debug("After x is $x");
 
=item info  : Something happend, but we recovered from it successfully
 
    $log->info("First server was accessible, but got data from the second");
 
=item warn  : Something negative but not detrimental
 
    $log->warn("No results from DB search, subsequent analysis impaired");
 
=item error : Something very wrong
 
    $log->error("Couldn't connect to database");

=back

=head2 MULTIPLE LOGS

To create multiple logs, e.g. in a loop, one log per input, remove the old log

    my $log_handle;
    foreach my $sequence (@sequences) {
        # Accession;
        my $acc = $sequence->display_id;
        # Start by removing any previous log handle
        Log::Any::Adapter->remove($log_handle);
        
        # A log just for this input file:
        $log_handle = Log::Any::Adapter->set('+SBG::Log',level=>'trace',file=>"$acc.log");
        
        $log->debug("Hey I'm working on $acc");
        unless ($sequence->length > 200) {
            $log->info("Skipping short sequence");
            next;
        }
        ...
    }


=head2 PERFORMANCE

There is negligible penalty for using the logging system when logging
messages are not printed. I.e. logging slows down an application. But logging
does not have to be completely avoided or turned off to increase speed. Simply
set the log level to e.g. C<error> to only log errors. Printing is the slowest 
part of logging. Stringification is the next slowest. You can get around this 
by doing something like:

    # Stringify a giant object, but only if debug mode
    use Data::Dumper
    # Evaluate this strinigification but only if debug is on
    $log->debug(Dumper $mega_object) if $log->is_debug;
 
The difference is that if C<$log> is set to C<warn> then the message will still 
not be printed, but C<Dumper> will stringify it, and then throw it away. If you
check C<is_debug> first, then the statement may never be executed. 

=head1 SEE ALSO

=over

=item L<Log::Any>

=item L<Log4perl>

=cut


package SBG::U::Log;
use strict;
use warnings;
use Log::Log4perl qw(:levels);
use Log::Any qw/$log/;
use Log::Any::Adapter;
use Path::Class;


sub new {
    my ($self, %ops) = @_;
    my ($name, $level, $file) = map { $ops{$_} } qw/name level file/;
    $name ||= '';
    $name = sprintf "%10s", $name;
    $file ||= '-'; 
    $level ||= 'WARN';
    $level = uc $level;

    my $h = `hostname --short`;
    chomp $h;
    $h = sprintf "%-15s", $h;
    my $pbs_jobid = sprintf "%8s", ($ENV{PBS_JOBID} || 'NotPBS');
    # Strip off any hostname
    $pbs_jobid =~ s/\..*$//;
        
    # Initialize system logger
    my $logger = Log::Log4perl->get_logger($file);

    # Default logging level 
    $logger->level(eval '$' . $level);
    
    # Log appenders (i.e. where the logs get sent)
    my $appender = $file eq '-' 
        ? Log::Log4perl::Appender->new(
            'Log::Log4perl::Appender::Screen',stderr=>1) 
        : Log::Log4perl::Appender->new(
            'Log::Dispatch::File',filename=>$file,mode=>'append');
        
    # Define log format for appender
    # $h host, %d date %M method %m message %n newline
    my $layout = Log::Log4perl::Layout::PatternLayout->new(
        "$name $h $pbs_jobid %d{yyyy-MM-dd HH:mm:ss} %-50M %m%n");
    # Set the layout of the appender
    $appender->layout($layout);
    # Register the appender with the logger
    $logger->add_appender($appender);

    # Log what script is running
    $logger->info("$0 $name " . join ' ', %ops);

    return $logger;
}


1;

