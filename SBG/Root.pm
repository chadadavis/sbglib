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
use Log::Log4perl qw(get_logger :levels);
use Log::Dispatch;
use FindBin;
use File::Spec::Functions;
use File::Basename;
use Config::IniFiles;
use Carp;

our $installdir;
our $logger;
our $config;

our @EXPORT = qw($installdir $logger $config);


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

    # In the working directory
    my $logfile = $config->val('log','file') || 'log.log';

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

    _init_dir();
    _init_ini();

# TODO DES
#     _init_log();
}


################################################################################
1;
