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

use SBG::Model;
use SBG::Interaction;
use SBG::U::DB;


has '_dbh' => (
    is => 'rw',
    );


# Biounit structures
has '_biounit' => (
    is => 'ro',
    isa => 'Str', # Better: MooseX::...Path
    default => '/g/russell2/3dr/data/final_paper/roberto/pdb_bio_units',
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
#     my $dbh=DBI->connect("DBI:CSV:f_dir=${f_dir};csv_eol=\n;csv_sep_char=\t");
    my $dbh=SBG::U::DB::connect('davis_3dr', 'speedy.embl.de');
    $self->_dbh($dbh);

    my $sth_chain = $dbh->prepare(
        join ' ',
        'SELECT',
        join(',', qw/PDB_FILE CHAIN1 MODEL1 COV1 CHAIN2 MODEL2 COV2/), 
        'FROM chain_templates ',
        'WHERE PROT1=? AND PROT2=?',
        );
    $self->_sth->put('chain_templates', $sth_chain);

    my $sth_domain = $dbh->prepare(
        join ' ',
        'SELECT',
        join(',', qw/DOM1 DOM2 PDB_FILE CHAIN1 START1 END1 CHAIN2 START2 END2/),
        'FROM domain_templates ',
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
    my ($self, $seq1, $seq2) = @_;
    my ($accno1, $accno2) = map {$_->display_id} ($seq1, $seq2);
    return unless $accno1 && $accno2;
    # Need to query in both directions? No, smallest first
    ($accno1, $accno2) = sort { $a cmp $b } ($accno1, $accno2);

    my @interactions; 

#     $self->_chains($accno1, $accno2); 
    $self->_domains($accno1, $accno2); 


    return @interactions;
} # search


#TODO DEL
use Data::Dumper;

sub _chains {
    my ($self, $accno1, $accno2) = @_;


    my $sth = $self->_sth->at('chain_templates');
    $log->debug("$accno1 $accno2");
    my $res = $sth->execute($accno1, $accno2); 
    while (my $h = $sth->fetchrow_hashref) {
        print Dumper $h;
    }


}


sub _domains {
    my ($self, $accno1, $accno2) = @_;

    my $sth = $self->_sth->at('domain_templates');
    $log->debug("$accno1 $accno2");
    my $res = $sth->execute($accno1, $accno2); 
    while (my $h = $sth->fetchrow_hashref) {
        print Dumper $h;
    }


}



################################################################################
__PACKAGE__->meta->make_immutable;
no Moose;
1;

__END__



        # Now we can create some domain models
        my $model1 = new SBG::Model(query=>$seq1,subject=>scopdomain($templ1),
                                    scores=>{'eval'=>$eval1,'seqid'=>$sid1});
        my $model2 = new SBG::Model(query=>$seq2,subject=>scopdomain($templ2),
                                    scores=>{'eval'=>$eval2,'seqid'=>$sid2});

        # Save interaction-specific scores in the interaction template
        my $iaction = new SBG::Interaction(
            models=>{$seq1=>$model1, $seq2=>$model2},
            scores=>{irmsd=>$irmsd, zscore=>$i2z, pval=>$i2p},
            );
