#!/usr/bin/env perl

=head1 NAME

SBG::Log - Logging setup

=head1 SYNOPSIS

 use SBG::Log;
 # Without any initialisation, WARN and ERROR go to STDERR, others ignored
 $logger->debug("x is: $x"); # not printed anywhere
 $logger->error("cannot open: $file)"; # printed to STDERR

 # initialize logging. Default level is 'WARN', default file is './log.log'
 SBG::Log::init('DEBUG', '/tmp/somewhere.log');
 $logger->debug("x is: $x"); # Appended to /tmp/somewhere.log
 $logger->trace("very detailed info"); # Not saved, since TRACE is higher 
 $logger->error("bad things"); # Saved to logfile, but no longer to STDERR

=head1 DESCRIPTION

By default there is no logging. WARN and ERROR messages will just go to
STDERR. When logging, WARN and ERROR and any other applicable messages all go to
the log file.

For a given level, all messages of higher severity are also logged. The list:

 TRACE DEBUG INFO WARN ERROR FATAL

E.g. when set to ERROR, only ERROR and FATAL get logged. When set to DEBUG,
everything but TRACE gets logged. 

NB There is negligible penalty for using the logging system when logging
messages are not printed. I.e. logging slows down an application. But logging
does not have to be completely avoided or turned off to increase speed. Simply
set the log level to e.g. B<$ERROR> to only log errors.


=head1 SEE ALSO

L<Log::Log4perl>

=cut

################################################################################

package SBG::Log;

use base qw/Exporter/;
our @EXPORT = qw($logger);

use Log::Log4perl qw(:levels :resurrect);

# No logging by default
# WARN and ERRROR messages to STDERR, others ignored
our $logger = bless {}, "SBG::_Dummy";


################################################################################


################################################################################
=head2 init

 Function: 
 Example : 
 Returns : 
 Args    : 

In order of increasing severity: $TRACE $DEBUG $INFO $WARN $ERROR $FATAL

=cut
sub init {
    my ($level, $logfile) = @_;
    $level ||= 'WARN';
    $logfile ||= 'log.log';

    # Initialize system logger
    $logger = Log::Log4perl->get_logger("sbg");

    # Default logging level 
    $logger->level(eval '$' . $level);
    
    # Log appenders (i.e. where the logs get sent)
    my $appender = Log::Log4perl::Appender->
        new("Log::Dispatch::File", filename => $logfile, mode => "append");
    
    # Define log format for appender
    my $layout = Log::Log4perl::Layout::PatternLayout->new("%5p %-30M %m%n");
    # Set the layout of the appender
    $appender->layout($layout);
    # Register the appender with the logger
    $logger->add_appender($appender);

    # First log message is the banner
    $logger->debug("\n\n", "=" x 80);

    return $logger;
}


################################################################################
1;


package SBG::_Dummy;

# warn/error messages diverted to STDERR
# Any other level messages (e.g. $DEBUG, etc) just get ignored
sub error {
    my $self = shift;
    return warn "@_\n";
}
sub warn { error(@_) }
sub fatal { error(@_) }

# These versions also call 'warn' in Log4Perl, need to catch them too
sub logwarn { error(@_) }
sub error_warn { error(@_) }

# Others get ignored
sub trace {1;}
sub debug {1;}
sub info {1;}



################################################################################
1;

