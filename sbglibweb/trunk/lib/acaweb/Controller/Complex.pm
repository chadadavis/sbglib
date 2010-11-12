package acaweb::Controller::Complex;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

acaweb::Controller::Complex - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


use SBG::U::Object qw/load_object/;
use File::Spec::Functions;
use SBG::ComplexIO::pdball;
use Moose::Autobox;


=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->body('Matched acaweb::Controller::Complex in Complex.');
}


sub complex :Path :Args(1) {
	my ($self, $c, $id) = @_;
	my $complex = $c->model('acamodel::Complex')->find({id=>$id});
	my $modelid = sprintf "%02d", $complex->model;
	my $fsresults = $c->config->{'fsresults'};

	my $modelfile = catfile($fsresults, $complex->basedir, $modelid . '.model');
    $c->log->debug("Reading ", $modelfile);
	my $complexobj = load_object($modelfile);
    $c->stash(complexobj => $complexobj);
    
    my $pdbgz = catfile($fsresults, $complex->basedir, $modelid . '.pdb.gz');
	$c->log->debug("Writing ", $pdbgz);
#	my $io = SBG::ComplexIO::pdb->new(file=>">$pdbgz", overwrite=>0);
	my $io = SBG::ComplexIO::pdball->new(file=>">$pdbgz", overwrite=>0);
	$io->write($complexobj);

    # TODO this probably needs to be relative to the application directory
    # Save this globally
    # Something like $c->uri_for('/') without the prefix: $c->req->base	
	my $webresults = $c->config->{'webresults'};
	my $pdbgzurl = catfile($webresults, $complex->basedir, $modelid . '.pdb.gz'); 
    $c->stash(pdbgzurl => $pdbgzurl);
    $c->log->debug("pdbgzurl:$pdbgzurl");

    $c->stash(complex => $complex);
    $c->stash(network => $complex->network_id);
    $c->stash(target => $complex->network_id->target_id);
    $c->stash(experiment => $complex->network_id->target_id->experiment_id);

    my $interactions = $complexobj->interactions->values;
    $c->stash(interactions => $interactions);
    # Not just the representatives, but all structures that went into model
    # I.e. each component may have multiple representatives
    $c->stash(models => $complexobj->all_models);    
	
}


=head1 AUTHOR

Chad Davis

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
