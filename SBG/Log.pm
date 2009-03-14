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

...

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

use base qw/Exporter/;
our @EXPORT = qw($logger);


################################################################################

sub _init {

    # Initialize system logger
    $logger = Log::Log4perl->get_logger("sbg");

    # Default logging level
    # In order of increasing severity: $TRACE $DEBUG $INFO $WARN $ERROR $FATAL
##    my $level = '$TRACE';
    my $level = '$INFO';
    $logger->level(eval $level);
    
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

#     warn "Logging to: $logfile\n";

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
sub AUTOLOAD { return 1; }


################################################################################
1;

