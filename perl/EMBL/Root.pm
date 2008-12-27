#!/usr/bin/env perl

=head1 NAME

EMBL::Root - 

=head1 SYNOPSIS

use base 'EMBL::Root';

=head1 DESCRIPTION


=head1 Functions

Details on functions implemented here are described below.
Private internal functions are generally preceded with an _

=cut

################################################################################

package EMBL::Root;
use Spiffy -base, -XXX;

use base "Bio::Root::Root";

use Carp;

use Log::Log4perl qw(get_logger :levels);
use Log::Dispatch;

use FindBin;
use File::Spec::Functions;
use Config::IniFiles;

our $logger;
our $inicfg;

our @EXPORT = qw($logger $inicfg);


sub _init_ini {

    my $inifile = catdir($FindBin::RealBin, 'embl.ini');
    our $inicfg = new Config::IniFiles(-file=>$inifile);

}


sub _init_log {

    my $logfile = $inicfg->val('log','file') || 'log.log';

    # Initialize system logger
    $logger = get_logger("embl");
    # Default logging level (of: trace debug info warn error fatal)
    $logger->level($INFO);
    
    # Log appenders (i.e. where the logs get sent)
    my $appender = Log::Log4perl::Appender->
        new("Log::Dispatch::File",
            filename => $logfile,
            mode => "append",
            );
    
    # Define log format for appender
    my $layout = Log::Log4perl::Layout::PatternLayout->
        new("%d %H $ENV{USER} PID:%P %5p> %M (%F{1}) Line: %L - %m%n");
    # Set the layout of the appender
    $appender->layout($layout);
    # Register the appender with the logger
    $logger->add_appender($appender);
    # First log message is the banner
    $logger->info("\n", "=" x 80);

}


BEGIN {
    _init_ini();
    _init_log();
}


################################################################################
1;

