#!/usr/bin/env perl

=head1 NAME

SBG::U::Config - Ini file parsing

=head1 SYNOPSIS

 my $thresh = config()->val("MySection", "MyThreshold");

This assumes there is a bit in the ini file like:

 [MySection]
 MyThreshold = 0.045

=head1 DESCRIPTION



=head1 SEE ALSO

L<Config::IniFiles>

=cut

################################################################################

package SBG::U::Config;

use base qw(Exporter);
our @EXPORT_OK = qw(config val);

use strict;
use warnings;

use File::Spec::Functions;
use File::Basename;
use Config::IniFiles;
use Carp;

# Singleton Config::IniFiles object
our $_config;
    

################################################################################
=head2 config

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub config {
    our $_config;
    # Update global if not yet initialized, or if new config file given
    if (@_ || ! defined($_config)) {
        $_config = _build_config(undef, @_);
    }
    return $_config;
}


################################################################################
=head2 val

 Function: 
 Example : 
 Returns : 
 Args    : 

Alias to L<Config::IniFiles::val>

=cut
sub val {
    return config()->val(@_);
}


################################################################################
=head2 _build_config

 Function: Loads initialisation file
 Example :
 Returns : 
 Args    :

Look for the config.ini in the directory of the caller's pakage.
Finally, check current directory

=cut
sub _build_config {
    my ($self,$inifile) = @_;
    $inifile ||= _find_config();
    my $_config;
    unless (defined($inifile) && -r $inifile) {
        carp "Cannot read configuration: $inifile\n";
        $_config = new Config::IniFiles;
    } else {
        $_config = new Config::IniFiles(-file=>$inifile);
    }
    return $_config;

} # _init_ini


################################################################################
=head2 _find_config

 Function:
 Example :
 Returns : 
 Args    :

Find a config file, as specific as possible. 
First the module's directory, 
Then the base directory of the module hierarchy.
Then the binary's directory
Then the shell's current directory

TODO should be cascaded, from least to most-specific, inheritance.

=cut
sub _find_config {
    my ($conffile) = @_;
    $conffile ||= 'config.ini';
    my ($callerpkg) = caller(0);
    # Determine the directory location of the calling package
    $callerpkg =~ s/::/\//g;
    $callerpkg .= '.pm';
    # Perl's %INC tells where modules where loaded from
    my $callerpkgfull = $INC{$callerpkg};
#     warn "callerpkgfull:$callerpkgfull:\n";

    my $pkgpath = catfile(dirname($callerpkgfull), $conffile);
    # The base of the module hierarchy
    my $basepath = $callerpkgfull;
    $basepath =~ s/$callerpkg//;
    # Distribution's lib root
    my $basefile = catfile($basepath, $conffile);
    # Perl lib root
    my $basefile1 = catfile($basepath, '..', $conffile);
    # Unpacked distribution root
    my $basefile2 = catfile($basepath, '..', $conffile);
    # The current directory of the client's shell
    my $nopath = $conffile;
    return $pkgpath if -r $pkgpath;
    return $basefile if -r $basefile;
    return $basefile1 if -r $basefile1;
    return $basefile2 if -r $basefile2;
    return $nopath if -r $nopath;
    return;
}


################################################################################
1;

