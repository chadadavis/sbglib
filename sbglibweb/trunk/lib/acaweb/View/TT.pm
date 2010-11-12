package acaweb::View::TT;

use strict;
use base 'Catalyst::View::TT';

__PACKAGE__->config(
    TEMPLATE_EXTENSION => '.tt',
    INTERPOLATE => 1,
    );

=head1 NAME

acaweb::View::TT - TT View for acaweb

=head1 DESCRIPTION

TT View for acaweb. 

=head1 SEE ALSO

L<acaweb>

=head1 AUTHOR

Chad Davis

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
