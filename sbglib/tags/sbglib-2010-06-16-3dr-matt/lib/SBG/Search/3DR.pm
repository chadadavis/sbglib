#!/usr/bin/env perl

=head1 NAME

SBG::Search::Roberto - 

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::SearchI> , L<SBG::Network> , L<SBG::Interaction> 

=cut

package SBG::Search::3DR;
use Moose;
with 'SBG::SearchI';
use Moose::Autobox;

use Log::Any qw/$log/;
use DBI;
use File::Basename;
use Sort::Key::Top qw/rnkeytopsort/;

# Must load SBG::Seq to get string overload on Bio::PrimarySeqI
use SBG::Seq;
use SBG::Domain;
use SBG::Model;
use SBG::Interaction;
use SBG::U::DB;

use SBG::U::List qw/flatten/;

has '_dbh' => ( is => 'rw', );

# Statement handles to query each table, indexed by table name
# Roberto_chain_templates.csv
# Roberto_domain_defs.csv
# Roberto_domain_templates.csv
has '_sth' => (
    is      => 'ro',
    isa     => 'HashRef',
    default => sub { {} },

);



has 'dbname' => (
    is => 'rw',
    isa => 'Str',
    default => '3dr_complexes',
    );
    

has 'dbtable' => (
    is => 'rw',
    isa => 'Str',
    default => 'interaction_templates_v3',
    );
    

sub BUILD {
    my ($self) = @_;

    my $dbh = SBG::U::DB::connect($self->dbname);

    # TODO invalid state if connection fails (too late, has to be in BUILDARGS)
    return unless defined $dbh;
    $self->_dbh($dbh);

    my $sth_interaction = $dbh->prepare(
        join ' ', 
        'SELECT',
        '*', 
        'FROM',
        $self->dbtable,
        'WHERE uniprot1=? AND uniprot2=?',
    );
    $self->_sth->put($self->dbtable, $sth_interaction );

    #    my $sth_docking = $dbh->prepare(
    #        join ' ',
    #        'SELECT',
    #        '*'
    #        'FROM docking_templates',
    #        'WHERE uniprot1=? AND uniprot2=?',
    #        );
    #    $self->_sth->put('docking_templates', $sth_docking);

    return $self;
}    # BUILD

=head2 search

 Function: 
 Example : 
 Returns : 
 Args    : Two L<Bio::Seq>


=cut

sub search {
    my ( $self, $seq1, $seq2, %ops ) = @_;

    # Need to query in both directions? No, smallest first
    # This is the case for the interaction_tempaltes, using uniprot
    # But after converting sgd to uniprot, won't be the case for docking ...
    ( $seq1, $seq2 ) =
      sort { $a->display_id cmp $b->display_id } ( $seq1, $seq2 );

    my @interactions;
    push @interactions, $self->_interactions( $seq1, $seq2, %ops );

    my $topn = $ops{'top'};

    # Only use docking-based templates where there weren't enough chain-based
    unless ( $topn && scalar(@interactions) >= $topn ) {
    	# TODO docking templates
#        push @interactions, $self->_docking( $seq1, $seq2, %ops );
    }

    if ($topn) {

        # Take top N interactions
        # This is the reverse numerical sort on the weight field
        @interactions = rnkeytopsort { $_->weight } $topn => @interactions;
    }
    $log->debug( scalar(@interactions), " interactions ($seq1,$seq2)" );

    return @interactions;
}    # search

# Matt's interaction summary: structures
sub _interactions {
    my ( $self, $seq1, $seq2 ) = @_;

    my $sth = $self->_sth->at($self->dbtable);
    my $res = $sth->execute( $seq1->display_id, $seq2->display_id );
    my @interactions;
    while ( my $h = $sth->fetchrow_hashref ) {

        my $dom1 = _mkdom( $h->slice( [qw/pdbid assembly model1 dom1/] ) );
        my $dom2 = _mkdom( $h->slice( [qw/pdbid assembly model2 dom2/] ) );

        my $mod1 = SBG::Model->new(
            query   => $seq1,
            subject => $dom1,
            scores  => { seqid => $h->{pcid1}, n_res => $h->{n_res1} },
        );
        my $mod2 = SBG::Model->new(
            query   => $seq2,
            subject => $dom2,
            scores  => { seqid => $h->{pcid2}, n_res => $h->{n_res2} },
        );

        my $iaction = SBG::Interaction->new(source=>$h->{source});
        $iaction->set( $seq1, $mod1 );
        $iaction->set( $seq2, $mod2 );
        $iaction->avg_scores(qw/seqid n_res/);
        
        my $avg_seqid = $iaction->scores->at('avg_seqid');
        # Scale to n_res to [0:100] (assuming max interface size of 1000
        my $avg_n_res = $iaction->scores->at('avg_n_res') / 10;
        # Save interprets z-score in the interaction
        $iaction->scores->put('interpretsz', $h->{z});
        
        my ( $wtnres, $wtseqid ) = ( .1, .9 );
    
        my $score =
          100 *
          ( $wtnres * $avg_n_res + $wtseqid * $avg_seqid ) /
          ( $wtnres * 100 + $wtseqid * 100 );

        $iaction->weight($score);

        push @interactions, $iaction;
    }
    return @interactions;

}


sub _mkdom {
    my ($pdbid, $assembly, $model, $descriptor) = flatten(@_);

    my $dom = SBG::Domain->new(
        pdbid      => $pdbid,
        assembly   => $assembly,
        model      => $model,
        descriptor => $descriptor,
    );
    return $dom;
}


__PACKAGE__->meta->make_immutable;
no Moose;
1;

__END__
