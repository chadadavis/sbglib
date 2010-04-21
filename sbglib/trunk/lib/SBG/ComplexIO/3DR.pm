#!/usr/bin/env perl

=head1 NAME

SBG::ComplexIO::3DR - 

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::Complex>

=cut



package SBG::ComplexIO::3DR;
use Moose;

with 'SBG::IOI';

use Carp;
use Moose::Autobox;
use LWP::Simple;
use Bio::SeqIO;
use IO::String;

use SBG::Model;
use SBG::Complex;



=head2 write

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub write {
    my ($self, $complex) = @_;
    return unless defined $complex;
    my $fh = $self->fh or return;

    print $fh '#=ID ', $complex->id, "\n" 
        if defined $complex->id;
    foreach my $key ($complex->keys) { print $fh '#=CP ', $key, "\n"; }
    print $fh '#=NA ', $complex->name, "\n" 
        if defined $complex->name;
    print $fh '#=DE ', $complex->description, "\n" 
        if defined $complex->description;

    return $self;
} # write



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

    my $complex = SBG::Complex->new;
    while (my $line = <$fh>) {
        # Skip to first record, beginning with ID line
        next unless $line =~ m|^#=ID (\S+)$|;
        $complex->id($1);
        $self->_sequences($complex) or return;
        while (my $subline = <$fh>) {
            last if $subline =~ m|^//$|;
            if ($subline =~ m|^#=NA (.*?)$|) { $complex->name($1) }
            elsif ($subline =~ m|^#=DE (.*?)$|) { $complex->description($1) }
            elsif ($subline =~ m|^#=CP (\S+)|) { 
#                 $complex->add_model($self->_mkmodel($1));
            }
        }
        return $complex;
    }
    $self->rewind;
    return;

} # read



=head2 _sequences

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub _sequences {
    my ($self, $complex) = @_;

    my $url = 'http://www.3drepertoire.org/Seqs?db=3DR&type_acc=Complex&source_acc=3DR&acc=';
    my $fasta_data = get($url . $complex->id);
    return unless $fasta_data;

    my $io = Bio::SeqIO->new(-fh=>IO::String->new($fasta_data),-format=>'Fasta');

    while (my $seq = $io->next_seq) {
        my $model = SBG::Model->new(query=>$seq);
        $complex->add_model($model);
    }

    return 1;

} # _sequences




__PACKAGE__->meta->make_immutable;
no Moose;
1;
