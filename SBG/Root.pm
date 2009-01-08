#!/usr/bin/env perl

=head1 NAME

SBG::Root - Base class of inheritance hierarchy, including useful tools

=head1 SYNOPSIS

Inherit from SBG::Root (using L<Spiffy>)

 use SBG::Root -base;

To also get the B<$self> variable automatically defined in your class methods:

 use SBG::Root -Base;

To also get the useful B<YYY> debugging function (also from L<Spiffy>), use:

 use SBG::Root -Base, -XXX;

Then you can simply prepend B<YYY> to any line of code to debug it

 YYY my $x = some_function($params);

To use the logging facility (L<Log::Log4perl>), just any of:

 $logger->trace("x is $x");
 $logger->debug("x is $x");
 $logger->info("x is $x");
 $logger->warn("x is $x");
 $logger->error("x is $x");
 $logger->fatal("x is $x");

Using an initialisation file (B<config.ini>) (via L<Config::IniFiles>) :

 my $thresh = $config->val("MySection", "MyThreshold");

This assumes there is a bit in the ini file like:

 [MySection]
 MyThreshold = 0.045


=head1 DESCRIPTION

Root class to be inherited from by all other classes.

=head1 SEE ALSO

L<Spiffy>, L<Log::Log4perl>, L<Config::IniFiles>

=cut

################################################################################

package SBG::Root;
use Spiffy -base, -XXX;

use warnings;

# Comment out this one line to stop all loggin
use Log::Log4perl qw(:levels :resurrect);

use Log::Dispatch;
use FindBin;
use File::Spec::Functions;
use File::Basename;
use Config::IniFiles;

# (Re-)export these
use Carp;
use Data::Dumper;
our $installdir;
our $logger;
our $config;

our @EXPORT = qw(carp Dumper $installdir $logger $config);


################################################################################
=head2 _undash

 Title   : _undash
 Usage   : _undash(%some_hash); # or for objects: $self->_undash();
 Function: Remove any leading '-' character from keynames in hash
 Example : (see below)
 Returns : Reference to the modified hash. 
 Args    : hash

Give a hash, or hash reference, remove any preceeding dash ('-') from keynames.

Modifies the given hash, and returns a reference to it as well. I.e. call by
reference semantics.

Useful in object constructors that receive named parameters as a hash. E.g

 sub new () {
     my ($class, %o) = @_;
     my $self = { %o };
     bless $self, $class;
     $self->_undash;
     return $self;
 }

=cut

sub _undash (\%) {
    my $o = shift;
    foreach my $old (keys %$o) {
        my $new = $old;
        $new =~ s/^-//;
        $o->{$new} = $o->{$old};
        delete $o->{$old};
    }
    return $o;
} # _undash


sub _init_dir {

    my $package_name = __PACKAGE__;
    $package_name =~ s/::/\//g;
    $package_name .= '.pm';
    my $path = $INC{$package_name} || '';
    our $installdir = dirname($path);

}


sub _init_ini {
    our $installdir;
    my $inifile = shift || catdir($installdir, 'config.ini');
    our $config;
    unless (-r $inifile) {
        carp "No configuration: $inifile\n";
        $config = new Config::IniFiles;
    } else {
        $config = new Config::IniFiles(-file=>$inifile);
    }
} # _init_ini


sub _init_log {

    # Default logging level
    my $level = $config->val('log', 'level') || '$INFO';
    # Log file written in the working directory
    my $logfile = $config->val('log','file') || (lc $level) . '.log';
    $logfile =~ s/^\$//;

    # Initialize system logger
    $logger = Log::Log4perl->get_logger("sbg");
    # Default logging level (of: trace debug info warn error fatal)
    $logger->level(eval $level);
    
    # Log appenders (i.e. where the logs get sent)
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

    # Keep this going to STDERR, so we know where to look for the log
#     print STDERR "Logging to: $logfile\n";

    # First log message is the banner
    $logger->debug("\n\n", "=" x 80);

}


BEGIN {

    _init_dir();
    _init_ini();

    # Only called when logging enabled
###l4p    _init_log();
###l4p     return;

    print STDERR "No logging\n";
    # Otherwise make $logger a dummy object
    $logger = bless {}, "SBG::_Dummy";
}

# Object of this class accept any method calls and always do nothing
package SBG::_Dummy;
use AutoLoader;
# Error messages diverted to STDERR
# Any other level messages (e.g. $DEBUG, etc) just get ignored
sub error {
    my $self = shift;
    return print STDERR "@_\n";
}
sub AUTOLOAD { return 1; }


################################################################################
1;

