#!/usr/bin/env perl

=head1 NAME

SBG::Template - A homologous structural template to model a protein sequence

=head1 SYNOPSIS

 use SBG::Template;


=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::SearchI> , L<SBG::Domain>

=cut


################################################################################

package SBG::Template;
use Moose;
with 'SBG::Storable';

use SBG::HashFields;

use SBG::Seq;
use SBG::Domain;

use overload (
    '""' => '_asstring',
    );


################################################################################
# Accessors


=head2 seq

=cut
has 'seq' => (
    is => 'rw',
    isa => 'Bio::Seq',
    );


=head2 domain

=cut
has 'domain' => (
    is => 'rw',
    isa => 'SBG::Domain',
    );


=head2 score

keys: eval seqid

=cut
hashfield 'score', 'scores';


sub _asstring {
    my ($self) = @_;
    return $self->seq . '(' . $self->domain . ')';
}


###############################################################################

1;

__END__
