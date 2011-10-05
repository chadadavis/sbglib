#
#
# BioPerl module for Bio::DB::SGD
#
# Based on Bio::DB::SwissProt from cjfields
#
# You may distribute this module under the same terms as perl itself

=head1 NAME

Bio::DB::SGD - Database object interface to SGD yeast database

=head1 SYNOPSIS

    use Bio::DB::SGD;

    $sgd = Bio::DB::SGD->new();

    $seq = $sgd->get_Seq_by_id('YHL030W'); # SGD ORF ID


=head1 DESCRIPTION

Fetches SGD ORF sequences (http://www.yeastgenome.org/) via UniProt http://www.uniprot.org)


This may return more than one sequence, in which case the first is returned.

=head1 AUTHOR - Chad A. Davis

Email Chad A. Davis E<lt>chad.a.davis@gmail.com E<gt>

=head1 APPENDIX

The rest of the documentation details each of the object
methods. Internal methods are usually preceded with a _

=cut

# Let the code begin...

package Bio::DB::SGD;
use strict;
use warnings;
our $VERSION = 20110929;
use 5.008;

# This ultimately inherits from Bio::Root::Root
use base qw/Bio::DB::WebDBSeqI/;

use LWP::Simple;
use IO::String;
use Bio::SeqIO;

# global vars
our $DEFAULTFORMAT = 'fasta';

sub new {
    my ($class, @args) = @_;
    my $self = $class->SUPER::new(@args);
    $self->{_baseurl} =
        "http://www.uniprot.org/uniprot/?format=fasta&query=cygd%20";

    return $self;
}

=head2 Routines from Bio::DB::RandomAccessI

=cut

=head2 get_Seq_by_id

 Title   : get_Seq_by_id
 Usage   : $seq = $db->get_Seq_by_id('YHL030W')
 Function: Gets a Bio::Seq object by its name
 Returns : a Bio::Seq object
 Args    : the id (as a string) of a sequence
 Throws  : "id does not exist" exception

=cut

sub get_Seq_by_id {
    my ($self, $id) = @_;
    my $queryurl = $self->{_baseurl} . $id;
    my $content  = get $queryurl;
    unless ($content) {
        $self->throw("id does not exist");
        return;
    }

    # Get the first sequence, in case multiple
    my $string = IO::String->new($content);
    my $seqio  = Bio::SeqIO->new(-fh => $string);
    my $seq    = $seqio->next_seq();
    return $seq;
}

=head2 default_format

 Title   : default_format
 Usage   : my $format = $self->default_format
 Function: Returns default sequence format for this module
 Returns : string
 Args    : none

=cut

sub default_format {
    return $DEFAULTFORMAT;
}

1;

__END__
