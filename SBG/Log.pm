#!/usr/bin/env perl

=head1 NAME

SBG::Log - Logging setup

=head1 SYNOPSIS

use SBG::Log;

To use the logging facility (L<Log::Log4perl>), just any of:

 $logger->trace("x is $x");
 $logger->debug("x is $x");
 $logger->info("x is $x");
 $logger->warn("x is $x");
 $logger->error("x is $x");
 $logger->fatal("x is $x");

=head1 DESCRIPTION

NB There is negligible penalty for using the logging system when logging
messages are not printed. I.e. logging slows down an application. But logging
does not have to be completely avoided or turned off to increase speed. Simply
set the log level to e.g. B<$ERROR> to only log errors.


=head1 SEE ALSO

L<Log::Log4perl>

=cut

################################################################################

package SBG::Log;

use Carp;
use Data::Dumper;

# Comment out just this one line to stop all logging
use Log::Log4perl qw(:levels :resurrect);

our $logger;
# In order of increasing severity: $TRACE $DEBUG $INFO $WARN $ERROR $FATAL
our $LEVEL = '$WARN';

use base qw/Exporter/;
our @EXPORT = qw($logger);


################################################################################

# Change the log level
sub level {
    my ($level) = @_;
    $LEVEL = $level;
    _init();
    $logger->info("Log level set to $LEVEL");
}


sub _init {

    # Initialize system logger
    $logger = Log::Log4perl->get_logger("sbg");

    # Default logging level
    $logger->level(eval $LEVEL);
    
    # Log appenders (i.e. where the logs get sent)
    # Log file written in the working directory
    my $logfile = 'log.log';
    my $appender = Log::Log4perl::Appender->
        new("Log::Dispatch::File",
            filename => $logfile,
            mode => "append",
            );
    
    # Define log format for appender
    my $layout = Log::Log4perl::Layout::PatternLayout->
#         new("%d %H $ENV{USER} PID:%P %5p> %M (%F{1}) Line: %L - %m%n");
#         new("%5p %15F{1} %4L %-25M - %m%n");
        new("%5p %-25M - %m%n");
    # Set the layout of the appender
    $appender->layout($layout);
    # Register the appender with the logger
    $logger->add_appender($appender);

    # First log message is the banner
    $logger->debug("\n\n", "=" x 80);

}


BEGIN {

    # Only called when logging enabled
###l4p if (1) { _init(); } else
    {
    warn "No logging\n";
    # Otherwise make $logger a dummy object
    $logger = bless {}, "SBG::_Dummy";
    }
}

# Object of this class accept any method calls and always do nothing
package SBG::_Dummy;
use AutoLoader;
# Error messages diverted to STDERR
# Any other level messages (e.g. $DEBUG, etc) just get ignored
sub error {
    my $self = shift;
    return warn "@_\n";
}
sub warn {
    my $self = shift;
    return warn "@_\n";
}
sub AUTOLOAD { return 1; }


################################################################################
1;

