package acaweb;
use Moose;
use namespace::autoclean;

use Catalyst::Runtime 5.80;

# Set flags and add plugins for the application
#
#         -Debug: activates the debug mode for very useful log messages
#   ConfigLoader: will load the configuration from a Config::General file in the
#                 application's home directory
# Static::Simple: will serve static files from the application's root
#                 directory

use Catalyst qw/
    -Debug
    ConfigLoader
    Static::Simple
/;

extends 'Catalyst';

our $VERSION = '0.01';
$VERSION = eval $VERSION;

# Configure the application.
#
# Note that settings in acaweb.conf (or other external
# configuration file that you set up manually) take precedence
# over this when using ConfigLoader. Thus configuration
# details given here can function as a default configuration,
# with an external configuration file acting as an override for
# local deployment.

__PACKAGE__->config(
    name => 'acaweb',
    # Disable deprecated behavior needed by old applications
    disable_component_resolution_regex_fallback => 1,
    # Base directory for outputs
    fsresults => "$ENV{AG}/aca/results",
    webresults => '/static/results',    
);

# Start the application
__PACKAGE__->setup();

# Logging
use SBG::U::Run qw/start_log/;
start_log('acaweb', loglevel=>'DEBUG');


=head1 NAME

acaweb - Catalyst based application

=head1 SYNOPSIS

    script/acaweb_server.pl

=head1 DESCRIPTION

[enter your description here]

=head1 SEE ALSO

L<acaweb::Controller::Root>, L<Catalyst>

=head1 AUTHOR

Chad A Davis, C<< <chad.a.davis at gmail.com> >>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
