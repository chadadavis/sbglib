package acaweb::Controller::Root;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config(namespace => '');

=head1 NAME

acaweb::Controller::Root - Root Controller for acaweb

=head1 DESCRIPTION

[enter your description here]

=head1 METHODS

=head2 index

The root page (/)

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;
    # TODO HOME PAGE
#    $c->response->body( $c->welcome_message );

}

=head2 default

Standard 404 error page

=cut

sub default :Path {
    my ( $self, $c ) = @_;
    $c->response->body( 'Page not found' );
    $c->response->status(404);
}


# Forwarding to a view automatic
sub end : ActionClass('RenderView') {}

# Forwarding will be effective if response->body is not set
#sub end : Private {
#    my ( $self, $c ) = @_;
#    $c->forward( $c->view('TT') );
#}
    


=head1 AUTHOR

Chad Davis

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
