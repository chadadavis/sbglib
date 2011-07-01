#!/usr/bin/env perl

=head1 NAME

SBG::Model - A homologous structural template to model a protein sequence

=head1 SYNOPSIS

 use SBG::Model;


=head1 DESCRIPTION


=head1 SEE ALSO


=cut


################################################################################

package SBG::Model;
use Moose;

with qw/
SBG::Role::Storable
SBG::Role::Scorable
/;


use overload (
    '""' => 'stringify',
    fallback => 1,
    );



################################################################################
=head2 query

 Function: The thing of interest, the thing being modelled
 Example : 
 Returns : 
 Args    : 


=cut
has 'query' => (
    is => 'rw',
    );


################################################################################
=head2 subject

 Function: The model for the query
 Example : 
 Returns : 
 Args    : 


=cut
has 'subject' => (
    is => 'rw',
    handles => [ qw/coords/ ],
    );


sub stringify {
    my ($self) = @_;
    return $self->query . '(' . $self->subject . ')';
}


###############################################################################
__PACKAGE__->meta->make_immutable;
no Moose;
1;


