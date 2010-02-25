#!/usr/bin/env perl

=head1 NAME

SBG::Split::Roberto - Divides a Bio::Seq into domains

=head1 SYNOPSIS



=head1 DESCRIPTION


=head1 TODO

Annotate L<Bio::Seq> with L<Bio::SeqFeature::Generic> first, then collapse it down.

=head1 SEE ALSO


=cut

################################################################################

package SBG::Split::Roberto;
use Moose;
with 'SBG::SplitI';

use Moose::Autobox;
use Log::Any qw/$log/;

use Bio::Seq;
use Bio::SeqFeature::Generic;
use DBI;


################################################################################
=head2 csvfile

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
has 'csvdir' => (
    is => 'rw',
    isa => 'Str',
    default => '/g/russell2/3dr/data/final_paper/roberto',
    );


has 'mingap' => (
    is => 'rw',
    isa => 'Int',
    default => 30,
    );


has '_dbh' => (
    is => 'rw',
    );


has '_sth' => (
    is => 'rw',
    );


################################################################################
=head2 BUILD

 Function: Sets up DB connection on object construction
 Example : 
 Returns : 
 Args    : 


=cut
sub BUILD {
    my ($self) = @_;
    my $f_dir = $self->csvdir;
    my $dbh=DBI->connect("DBI:CSV:f_dir=${f_dir};csv_eol=\n;csv_sep_char=\t");

    my $sth = $dbh->prepare(
        join ' ',
        'SELECT',
        join(',', qw/PROT DOM EVALUE ID START END DOM_ID/),
        'FROM',
        'yeast_domains.txt',
        'where PROT=?',
	);

    $self->_dbh($dbh);
    $self->_sth($sth);
    return $self;

} # BUILD


################################################################################
=head2 split

 Function: Looks up domain annatations and splits sequence on domains
 Example : 
 Returns : Array of L<Bio::Seq>, covering entirety of original sequence
 Args    : 

Domain boundaries are expanded/contracted to avoid short fragments. Unannotated
domains are labeled as dummy domains. The returned sequences cover the entire
length of the original sequence.

=cut
sub split {
    my ($self, $seq) = @_;
    # Look for domain hits for this sequence ID
    my $feats = $self->query($seq);
    # Merge domain boundaries that are close togther
    $feats = $self->_smooth_feats($seq, $feats);
    # Add dummy features for the gap regions between annotated domains
    $feats = $self->_fill_feats($seq, $feats);
    # Associate each feature with the one sequence
    $feats->map(sub{$_->attach_seq($seq)});
    # Subsequence for reach feature
    my $subseqs = $feats->map(sub{_subseq_feat($seq, $_)});
    return $subseqs;
}


################################################################################
=head2 query

 Function: The raw domain feature annotations
 Example : 
 Returns : ArrayRef of L<Bio::SeqFeature::Generic>
 Args    : 

These are not yet attached to the sequence. Do that with 

 $eachfeature->attach_seq($seq);

The display_name of each feature contains the domain name

=cut
sub query {
    my ($self, $seq) = @_;

    my $dbhits = $self->_hits($seq);
    # Convert DB hash to Bio::SeqFeature::Generic
    my $feats = $dbhits->map(sub{_hit2feat($_)});
    return $feats;
}


sub _hits {
    my ($self, $seq) = @_;

    my $sth = $self->_sth;
    my $res = $sth->execute($seq->display_id);
    my $hits = [];
    while (my $h = $sth->fetchrow_hashref) {
        $hits->push($h);
    }
    # Put domains in the order that they occur in on sequence
#     $hits = $hits->sort(sub{$a->{START}<=>$b->{START}});
    $hits = [sort {$a->{START} <=> $b->{START} } @$hits];
    return $hits;
}


sub _hit2feat {
    my ($hit) = @_;
    my $feat = Bio::SeqFeature::Generic->new(
        -start => $hit->{START},
        -end => $hit->{END},
        -display_name => $hit->{DOM},
        -score => $hit->{EVALUE},
        -source_tag => 'yeast_domains',
        );
    return $feat;
}


# Smooth/expand the boundaries. 
# No short fragments between domains, nor at begin/end of sequence
sub _smooth_feats {
    my ($self, $seq, $feats) = @_;

    # If any two boundaries are two close together, collapses them into one
    for (my $i = 0; $i < $feats->length - 1; $i++) {
        my ($this, $next) = ($feats->[$i], $feats->[$i+1]);
        # Find the midpoint and delete the previous boundary
        if ($next->start - $this->end < $self->mingap) {
            my $mid = int (($next->start + $this->end) / 2);
            $this->end($mid);
            $next->start($mid+1);
        }
    }

    # Stretch ends, if close enough
    if ($feats->[0] && $feats->[0]->start < $self->mingap) {
        $feats->[0]->start(1);
    }
    if ($feats->[-1] && $seq->length - $feats->[-1]->end < $self->mingap) {
        $feats->[-1]->end($seq->length);
    }

    return $feats;

}


sub _fill_feats {
    my ($self, $seq, $feats) = @_ ;

    my $full = [];
    # Insert one dummy domain before each domain when there's a gap
    my $prev = 0;
    for (my $i = 0; $i < $feats->length; $i++) {
        my $this = $feats->[$i];
        if ($this->start - $prev > 1) {
            $full->push(_dummy($prev+1, $this->start-1));
        }
        $full->push($this);
        $prev = $this->end
    }

    # And append a dummy domain at the end, if necessary
    if ($seq->length - $prev > 1) {
        $full->push(_dummy($prev+1, $seq->length));
    }

    return $full;

} # _fill_feats


sub _dummy {
    my ($start, $end) = @_;
    return Bio::SeqFeature::Generic->new(
        -start => $start,
        -end => $end,
        -display_name => 'DUMMY',
        -source_tag => 'yeast_domains',
        );
}


sub _subseq_feat {
    my ($seq, $feat) = @_;
    my $subseq = $feat->seq;
    # Put domain label into sequence description
    $subseq->desc($feat->display_name . ' ' . $seq->desc);
    return $subseq;
}


################################################################################
__PACKAGE__->meta->make_immutable;
no Moose;
1;


