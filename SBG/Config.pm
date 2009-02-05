#!/usr/bin/env perl

=head1 NAME

SBG::Config - Ini file parsing

=head1 SYNOPSIS

 my $thresh = $config->val("MySection", "MyThreshold");

This assumes there is a bit in the ini file like:

 [MySection]
 MyThreshold = 0.045

=head1 DESCRIPTION



=head1 SEE ALSO

L<Moose::Role>, L<Config::IniFiles>

=cut

################################################################################

package SBG::Config;

use base qw(Exporter);
our @EXPORT_OK = qw(config val);

use File::Spec::Functions;
use File::Basename;
use Config::IniFiles;
use Carp;

our $config;

    
################################################################################


sub config {
    our $config;
    $config ||= _build_config(undef, @_);
    return $config;
}

sub val {
    our $config;
    return $config->val(@_);
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
    unless (-r $inifile) {
        carp "No configuration: $inifile\n";
        return new Config::IniFiles;
    }
    return new Config::IniFiles(-file=>$inifile);

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
    my $pkgpath = catfile(dirname($callerpkgfull), $conffile);
    # The base of the module hierarchy
    my $basepath = $callerpkgfull;
    $basepath =~ s/$callerpkg//;
    $basepath = catfile($basepath, $conffile);
    # The current directory of the shell
    my $nopath = $conffile;
    return $pkgpath if -r $pkgpath;
    return $basepath if -r $basepath;
    return $nopath if -r $nopath;
    return;
}

################################################################################
1;

