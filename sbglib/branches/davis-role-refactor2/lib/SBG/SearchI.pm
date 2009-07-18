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
use Module::Load;
use SBG::Domain;

=head2 objtype

The sub-objtype to use for any dynamically created objects. Should be
L<SBG::Domain> or a sub-class of that. Default "L<SBG::Domain>" .

=cut
has 'objtype' => (
    is => 'rw',
    isa => 'ClassName',
    required => 1,
    default => 'SBG::Domain',
    );

# ClassName does not validate if the class isn't already loaded. Preload it here.
before 'objtype' => sub {
    my ($self, $classname) = @_;
    return unless $classname;
    Module::Load::load($classname);
};


################################################################################
=head2 search

 Function: Search for homologous interaction template structure for two proteins.
 Example : my $iaction = search($seqa, $seqb);
 Returns : L<SBG::Interaction>
 Args    : Two L<Bio::Seq>s


=cut
requires 'search';


################################################################################
no Moose::Role;
1;

