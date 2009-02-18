#!/usr/bin/env perl

=head1 NAME

SBG::SearchI - Protein interaction template search L<Moose::Role>

=head1 SYNOPSIS

 package MySearcher;
 use Moose;
 with 'SBG::SearchI'; 

=head1 DESCRIPTION

If your class uses this role, it will need to define all the methods below.

=head1 SEE ALSO

L<SBG::Network> , L<Moose::Role>

=cut

################################################################################

package SBG::SearchI;
use Moose::Role;


################################################################################
=head2 search

 Function: Search for homologous interaction template structure for two proteins.
 Example : my $iaction = search($seqa, $seqb);
 Returns : L<SBG::Interaction>
 Args    : Two L<Bio::Seq>s


=cut
requires 'search';


################################################################################
1;

