#!/usr/bin/env perl

=head1 NAME

SBG::Seq - Additions to Bioperl's L<Bio::Seq>

=head1 SYNOPSIS

 use SBG::Seq;


=head1 DESCRIPTION

Simple extensions to L<Bio::Seq> to define stringificition, string equality and
string comparison, all based on the B<accession_number> field.

=head2 SEE ALSO

L<Bio::Seq>

=cut

################################################################################

package SBG::Seq;
use Moose;
extends 'Bio::Seq';
with 'SBG::Storable';

use overload (
    '""' => '_asstring',
    'cmp' => '_compare',
    fallback => 1,
    );

################################################################################

sub new () {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    bless $self, $class;
    return $self;
}

sub _asstring {
    my ($self) = @_;
    return $self->accession_number;
}

sub _compare {
    my ($a, $b) = @_;
    return $a->accession_number cmp $b->accession_number;
}

###############################################################################
__PACKAGE__->meta->make_immutable;
1;


