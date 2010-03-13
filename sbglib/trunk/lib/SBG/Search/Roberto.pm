#!/usr/bin/env perl

=head1 NAME

SBG::Search::Roberto - 

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::SearchI> , L<SBG::Network> , L<SBG::Interaction> 

=cut

################################################################################

package SBG::Search::Roberto;
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


has '_dbh' => (
    is => 'rw',
    );


# Biounit structures
has '_biounit' => (
    is => 'rw',
    isa => 'Str', # Better: MooseX::...Path
    default => '/g/russell2/3dr/data/final_paper/roberto/pdb_bio_units',
#     default => '/usr/local/data/pdb-biounit-roberto',
    );


# Statement handles to query each table, indexed by table name
# Roberto_chain_templates.csv 
# Roberto_domain_defs.csv 
# Roberto_domain_templates.csv
has '_sth' => (
    is => 'ro',
    isa => 'HashRef',
    default => sub { {} },
    );


sub BUILD {
    my ($self) = @_;

    my $f_dir = dirname(__FILE__);
    my $dbh=SBG::U::DB::connect('davis_3dr', 'speedy.embl.de');
    $self->_dbh($dbh);

    my $sth_chain = $dbh->prepare(
        join ' ',
        'SELECT',
        join(',', 
             qw/PDB ASSEMBLY CHAIN1 MODEL1 ID1 COV1 CHAIN2 MODEL2 ID2 COV2 CONTACTS/), 
        'FROM chain_templates ',
        'WHERE PROT1=? AND PROT2=?',
        );
    $self->_sth->put('chain_templates', $sth_chain);

    my $sth_domain = $dbh->prepare(
        join ' ',
        'SELECT',
        join(',', qw/DOM1 DOM2 PDB CHAIN1 ID1 START1 END1 CHAIN2 ID2 START2 END2/),
        'FROM domain_templates',
        'WHERE PROT1=? AND PROT2=?',
        );
    $self->_sth->put('domain_templates', $sth_domain);

    my $sth_defs = $dbh->prepare(
        join ' ',
        'SELECT',
        join(',', qw/START END/),
        'FROM domain_defs ',
        'WHERE PROT=? AND DOM=?',
        );
    $self->_sth->put('domain_defs', $sth_domain);

    return $self;
} # BUILD


=head2 search

 Function: 
 Example : 
 Returns : 
 Args    : Two L<Bio::Seq>


=cut
sub search {
    my ($self, $seq1, $seq2, %ops) = @_;

    # Need to query in both directions? No, smallest first
    ($seq1, $seq2) = sort { $a->display_id cmp $b->display_id } ($seq1, $seq2);

    my @interactions;
    push @interactions, $self->_chains($seq1, $seq2);

    my $topn = $ops{'top'};
    # Only use Domain-based templates where there weren't enough chain-based
    unless ($topn && scalar(@interactions) >= $topn) {
        push @interactions, $self->_domains($seq1, $seq2);
    }

    if ($topn) {
        # Take top N interactions
        # This is the reverse numerical sort on the weight field
        @interactions = rnkeytopsort { $_->weight } $topn => @interactions;
    }
    $log->debug(scalar(@interactions), " interactions ($seq1,$seq2)");

    return @interactions;
} # search


# Full chain templates
sub _chains {
    my ($self, $seq1, $seq2) = @_;

    my $sth = $self->_sth->at('chain_templates');
    my $res = $sth->execute($seq1->display_id, $seq2->display_id);
    my @interactions;
    while (my $h = $sth->fetchrow_hashref) {
        my $dom1 = $self->_mkchain(
            $h->{PDB},$h->{CHAIN1},$h->{ASSEMBLY}, $h->{MODEL1});
        my $dom2 = $self->_mkchain(
            $h->{PDB},$h->{CHAIN2},$h->{ASSEMBLY}, $h->{MODEL2});
        my $mod1 = SBG::Model->new(query=>$seq1,subject=>$dom1,
                                   scores=>{cov=>$h->{COV1},seqid=>$h->{ID1}});
        my $mod2 = SBG::Model->new(query=>$seq2,subject=>$dom2,
                                   scores=>{cov=>$h->{COV2},seqid=>$h->{ID2}});

        my $iaction = SBG::Interaction->new;
        $iaction->set($seq1, $mod1);
        $iaction->set($seq2, $mod2);
        $iaction->avg_scores(qw/cov seqid/);
        $iaction->scores->put('contacts', $h->{CONTACTS});
        $iaction->weight($iaction->scores->at('avg_seqid'));

        push @interactions, $iaction;
    }
    return @interactions;

} # _chains


# Templates from Pfam domains
sub _domains {
    my ($self, $seq1, $seq2) = @_;

    my $sth = $self->_sth->at('domain_templates');
    my $res = $sth->execute($seq1->display_id, $seq2->display_id); 
    my @interactions;
    while (my $h = $sth->fetchrow_hashref) {
        my $dom1 = $self->_mkdom(
            $h->{PDB},$h->{CHAIN1},$h->{START1},$h->{END1});
        my $dom2 = $self->_mkdom(
            $h->{PDB},$h->{CHAIN2},$h->{START2},$h->{END2});
        my $mod1 = SBG::Model->new(query=>$seq1,subject=>$dom1,
                                   scores=>{seqid=>$h->{ID1}});
        my $mod2 = SBG::Model->new(query=>$seq2,subject=>$dom2,
                                   scores=>{seqid=>$h->{ID2}});
            
        my $iaction = SBG::Interaction->new();
        $iaction->set($seq1, $mod1);
        $iaction->set($seq2, $mod2);
        $iaction->avg_scores(qw/seqid/);
        $iaction->weight($iaction->scores->at('avg_seqid'));
        push @interactions, $iaction;
    }
    return @interactions;
} # _domains;


sub _mkdom { 
    my ($self, $pdb, $chain, $start, $end, $assem, $model) = @_;

    my $dom = SBG::Domain->new(pdbid=>$pdb,
                               descriptor=>
                               join(' ',$chain,$start,'_','to',$chain,$end,'_'));
    return $dom;
}


sub _mkchain { 
    my ($self, $pdb, $chain, $assem, $model) = @_;

    my $dom = SBG::Domain->new(pdbid=>$pdb,
                               descriptor=>"CHAIN $chain");
    if ($assem && $model) {
        my $base = $self->_biounit;
        my $path = "${base}/${pdb}.pdb${assem}.model${model}.gz";
        $dom->file($path);
    }
    return $dom;
}


################################################################################
__PACKAGE__->meta->make_immutable;
no Moose;
1;

__END__

