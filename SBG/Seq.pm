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
use SBG::Root -base, -XXX;
use base qw(Bio::Seq);

use overload (
    '""' => '_asstring',
    'cmp' => '_compare',
    'eq' => '_equal',

    );

################################################################################

sub new () {
    my $class = shift;
    # Delegate to parent class
    my $self = new Bio::Seq(@_);
    # And add our ISA spec
    bless $self, $class;
    # Is now both a Bio::Seq and an SBG::Seq
    return $self;
}

sub _asstring {
    my ($self) = @_;
    return $self->accession_number;
}

sub _equal {
    my ($a, $b) = @_;
    return 0 == _compare($a, $b);
}

sub _compare {
    my ($a, $b) = @_;
    return $a->accession_number cmp $b->accession_number;
}


###############################################################################

1;


