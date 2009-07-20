#!/usr/bin/env perl

=head1 NAME

SBG::Eval - Evaluation routine to test accuracy of assembly of test complexes

=head1 SYNOPSIS

 use SBG::Eval;

=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::NetworkIO> , L<SBG::ComplexIO>

=cut

################################################################################

package SBG::Eval;
use Moose;

with 'SBG::Role::Storable';
with 'SBG::Role::Clonable';





################################################################################
__PACKAGE__->meta->make_immutable;
no Moose;
1;



