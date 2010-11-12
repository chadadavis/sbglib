package acaweb::Controller::Experiment;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

acaweb::Controller::Experiment - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    my @hits = $c->model('acamodel::Experiment')->all;
    # These are in the order they were declared in the database
    my @columns = $c->model('acamodel::Experiment')->result_source->columns;
    $c->log->debug("columns @columns");
    $c->stash(hits => \@hits);
    $c->stash(columns => \@columns);

}


sub experiment :Path :Args(1) {
    my ( $self, $c, $arg) = @_;

    my $experiment = $c->model('acamodel::Experiment')->find({id=>$arg});
    $c->stash(experiment=>$experiment);
        
    my $complex_table = $c->model('acamodel::Complex');
    my @complexes = $complex_table->search(
        {'experiment_id.id'=>$arg},
        {join=> { 'network_id' => { 'target_id' => 'experiment_id' } } }
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
