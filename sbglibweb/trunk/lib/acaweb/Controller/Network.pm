package acaweb::Controller::Network;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

acaweb::Controller::Network - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


sub network :Path :Args(1) {
    my ( $self, $c, $arg) = @_;

# Shortcut: no join
#    my @complexes = $c->model('acamodel::Complex')->search({network_id=>$arg})->all;

    my $network= $c->model('acamodel::Network')->find({id=>$arg});
    my $target = $network->target_id;
    my $experiment = $target->experiment_id;
    $c->stash(experiment=>$experiment,target=>$target,network=>$network);
    
    my $complex_table = $c->model('acamodel::Complex');
    my @complexes =
        $complex_table->search({'network_id.id'=>$arg},{join=>'network_id'})->all; 
       
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
