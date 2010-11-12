package acaweb::Model::acamodel;

use strict;
use base 'Catalyst::Model::DBIC::Schema';

__PACKAGE__->config(
    schema_class => 'acaschema',
    connect_info => [
        'dbi:mysql:database=aca;host=pevolution;user=%',
        
    ],
);

=head1 NAME

acaweb::Model::acamodel - Catalyst DBIC Schema Model
=head1 SYNOPSIS

See L<acaweb>

=head1 DESCRIPTION

L<Catalyst::Model::DBIC::Schema> Model using schema L<acaschema>

=head1 AUTHOR

Chad Davis

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
