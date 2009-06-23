#!/usr/bin/env perl

=head1 NAME

SBG::Search::CSV - Custom search interface, for defining custom interactions

=head1 SYNOPSIS

 use SBG::Search::CSV;

=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::Search> , L<SBG::Network> , L<SBG::Interaction> 

=cut

################################################################################

package SBG::Search::CSV;
use Moose;

with 'SBG::SearchI';

use SBG::InteractionIO;
use SBG::Interaction;
use SBG::Template;
use SBG::Domain;

use SBG::Types;
use SBG::U::Log qw/log/;


has 'file' => (
    is => 'rw',
    isa => 'SBG.File',
    );


################################################################################
=head2 search

 Function:
 Example :
 Returns : 
 Args    :

=cut
sub search {
   my ($self, $seq1, $seq2) = @_;

   my @templates = $self->_grep_db($seq1, $seq2);

   return @templates;

}


################################################################################
=head2 _grep_db

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub _grep_db {
    my ($self, $seq1, $seq2) = @_;
    my ($comp1, $comp2) = map {$_->accession_number} ($seq1, $seq2);

    # Grep the lines from database, space-delimited, either order
    my $cmd = "egrep \'^ *($comp1 +$comp2|$comp2 +$comp1) +\' " . $self->file;
    my @lines = `$cmd`;
    $logger->trace(sprintf "pair: %3d hits: %s -- %s",
                   scalar(@lines), $comp1, $comp2);

    my @interactions = map { SBG::InteractionIO::parse $_ } @lines;
    return @interactions;

} # _grep_db


################################################################################
__PACKAGE__->meta->make_immutable;
1;
