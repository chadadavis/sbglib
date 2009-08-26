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

use File::Temp qw/tempfile/;

use SBG::InteractionIO;
use SBG::Interaction;
use SBG::Model;
use SBG::Domain;
use SBG::Seq;
use SBG::Node;

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
    my ($comp1, $comp2) = map {$_->accession_number} ($seq1, $seq2);

    # Grep the lines from database, space-delimited, either order
    # Save in tempfile
    my $fh = new File::Temp;
    my $tpath = $fh->filename;
    my $grep = "egrep \'^ *($comp1 +$comp2|$comp2 +$comp1) +\' ";
    my $cmd = join(" ", $grep, $self->file, ">$tpath");
    $fh->close;

    unless (-s $tpath) {
        log->debug("$comp1 $comp2 : 0 hits");
        return;
    }

    my $io = new SBG::InteractionIO::CSV(file=>$tpath);
    my @interactions;
    while (my $line = $io->read) {
        push @interactions, $line;
    }
    
    log->debug("$comp1 $comp2 : ", scalar(@interactions), " hits");

    return @interactions;

} # _grep_db


################################################################################
__PACKAGE__->meta->make_immutable;
no Moose;
1;
