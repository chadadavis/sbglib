#!/usr/bin/env perl

=head1 NAME

SBG::NetworkIO::3DR - 

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::Network>

=cut

package SBG::NetworkIO::3DR;
use Moose;

with 'SBG::IOI';

use Moose::Autobox;
use LWP::Simple;
use Bio::SeqIO;
use IO::String;

use SBG::Network;
use SBG::Node;

=head2 write

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut

sub write {
    my ($self, $net) = @_;
    return unless defined $net;
    my $fh = $self->fh or return;

    print $fh '#=ID ?', "\n";
    foreach my $node ($net->nodes) { print $fh '#=CP ', $node, "\n"; }
    print $fh '#=NA ?',  "\n";
    print $fh '#=DE ? ', "\n";

    return $self;
}    # write

=head2 read

 Title   : 
 Usage   : 
 Function: 
 Example : 
 Returns : 
 Args    : 

=cut

sub read {
    my ($self) = @_;
    my $fh = $self->fh or return;

    while (my $line = <$fh>) {

        # Skip to first record, beginning with ID line
        next unless $line =~ m|^#=ID (\S+)$|;
        my $net = $self->_sequences($1);
        return $net;
    }
    $self->rewind;
    return;

}    # read

=head2 _sequences

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut

sub _sequences {
    my ($self, $id) = @_;

    my $url =
        'http://www.3drepertoire.org/Seqs?db=3DR&type_acc=Complex&source_acc=3DR&acc=';
    my $fasta_data = get($url . $id);
    return unless $fasta_data;

    my $io = Bio::SeqIO->new(
        -fh     => IO::String->new($fasta_data),
        -format => 'Fasta',
    );
    my $net = SBG::Network->new;
    while (my $seq = $io->next_seq) {
        my $node = SBG::Node->new($seq);
        $net->add_node($node);
    }

    return $net;

}    # _sequences

__PACKAGE__->meta->make_immutable;
no Moose;
1;
