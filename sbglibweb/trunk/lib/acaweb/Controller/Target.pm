package acaweb::Controller::Target;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

acaweb::Controller::Target - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub target :Path :Args(1) {
    my ( $self, $c, $arg) = @_;

    my $target = $c->model('acamodel::Target')->find({id=>$arg});
    my $experiment = $target->experiment_id;
    $c->stash(experiment=>$experiment,target=>$target);
        
    my $complex_table = $c->model('acamodel::Complex');
    my @complexes = $complex_table->search(
        {'target_id.id'=>$arg},
        {join=> { 'network_id' => 'target_id' } }
    )->all; 
                   
    $c->stash(complexes => \@complexes);
    $c->stash(template => 'models.tt');
}


=head1 AUTHOR

Chad Davis

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
