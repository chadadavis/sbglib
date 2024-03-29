#!/usr/bin/env perl

=head1 NAME

SBG::Model - A homologous structural template to model a protein sequence

=head1 SYNOPSIS

 use SBG::Model;


=head1 DESCRIPTION



Model::input : the original full input Bio::Seq
Model::query : the query sequence, as aligned in the Blast hit
Model::aln : the alignment from the hit
Model::subject : the subject of the hit, i.e. the template found
Model::structure : the structural representation of the template

=head1 SEE ALSO


=cut

package SBG::Model;
use Moose;

with qw/
    SBG::Role::Storable
    SBG::Role::Scorable
    SBG::Role::Transformable
    /;

# TODO DES needs to implement a StructureI interface, defining e.g. 'transform'

use Scalar::Util qw/refaddr/;
use Log::Any qw/$log/;

use overload (
    '""'     => 'stringify',
    fallback => 1,
);

=head2 query

 Function: The thing of interest, the thing being modelled
 Example : 
 Returns : 
 Args    : 


=cut

has 'query' => (is => 'rw',);

=head2 subject

 Function: The template for the query
 Example : 
 Returns : 
 Args    : 


=cut

has 'subject' => (is => 'rw',);

=head2 structure

If a component to be modelled already has a monomeric structure. 

Otherwise the template provides the structure

=cut

has 'structure' => (
    is         => 'rw',
    does       => 'SBG::DomainI',
    handles    => [qw/coords transformation/],
    lazy_build => 1,
);

sub _build_structure {
    my ($self,) = @_;

    # The template is the default structure, if none given
    return $self->subject;
}

=head2 input

 Function: Original input, e.g. original Bio::Seq
 Example : 
 Returns : 
 Args    : 



=cut

has 'input' => (is => 'rw',);

=head2 aln

Lazy way to keep track of the alignment between the query and the subject
=cut

has 'aln' => (is => 'rw',);

=head2 coverage

 Function: 
 Example : 
 Returns : [0.0-100.0] Percent of the sequence overlap between input and model
 Args    : 



=cut

has 'coverage' => (
    is         => 'rw',
    lazy_build => 1,
);

sub _build_coverage {
    my ($self) = @_;
    my $model_len = $self->subject->seq->length;
    my $input = $self->input || $self->query;
    my $input_len = $input->length;
    return 100.0 * $model_len / $input_len;
}

sub stringify {
    my ($self) = @_;
    my $string = $self->gene || $self->query;
    my $subject = $self->subject;
    $string .= '(' . $subject . ')' if $subject;
    return $string;
}

sub transform {
    my ($self, $matrix) = @_;
    my $subject = $self->subject;
    $subject->transform($matrix);

    my $structure = $self->structure;

    # If Model contains it's own strutural representation in addition to template
    if (refaddr($structure) != refaddr($subject)) {
        $structure->transform($matrix);
    }
    return $self;
}

=head2 gene

Hack to extract the first word of description, assumed to be the gene name

TODO this needs to be pulled from, e.g.: 

 http://www.uniprot.org/uniprot/Q3E7Y3.xml

=cut

sub gene { name(@_) }

=head2 name



=cut

sub name {
    my ($self) = @_;

    # Alnternative when no gene name
    #    my $query = $self->query;

    # Use the original sequence input here, as query is the result of the
    # Blast search

    my $query = $self->input;
    return unless defined($query);
    my $gene;
    if ($query->isa('Bio::PrimarySeqI')) {
        my $desc = $query->desc() || $query->display_id;
        $log->debug($desc);
        ($gene) = $desc =~ /^(\S+)/;
        $log->debug($gene);
    }

    # Otherwise just stringify the query objecct
    return $gene || "$query";

}

__PACKAGE__->meta->make_immutable;
no Moose;
1;

