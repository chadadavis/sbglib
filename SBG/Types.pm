#!/usr/bin/env perl

=head1 NAME

SBG::Types - 

=head1 SYNOPSIS

 use SBG::Types

=head1 DESCRIPTION

...

=head1 SEE ALSO

L<Moose::Util::TypeConstraints>

=cut

################################################################################

package SBG::Types;
use Moose;
use Moose::Util::TypeConstraints;

subtype 'File' 
    => as 'Str'
    => where { -r $_ && -s $_ };

subtype 'Dir'
    => as 'Str'
    => where { -d $_ };

subtype 'ChainID'
    => as 'Str',
    => where { /^[A-Za-z0-9_]$/ };

