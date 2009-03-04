#!/usr/bin/env perl

=head1 NAME

SBG::ComplexIO - Reads L<SBG::Complex>s using L<SBG::DomainIO>

=head1 SYNOPSIS

 use SBG::ComplexIO;


=head1 DESCRIPTION



=SEE ALSO

L<SBG::Complex> , L<SBG::DomainIO>

=cut

################################################################################

package SBG::ComplexIO;
use Moose;
extends 'SBG::DomainIO';

use IO::String;

use SBG::Complex;
use SBG::Transform;



################################################################################
=head2 read

 Function: Read many L<SBG::Domain> objects from a STAMP file
 Example :
 Returns : 
 Args    :


=cut
override 'read' => sub {
    my ($self) = @_;
    my $complex = new SBG::Complex();
    while (my $dom = super()) {
        # Add Dom to complex
        $complex->template($dom->uniqueid, $dom);
    }
    return $complex;
};


################################################################################
=head2 write

 Function:
 Example :
 Returns : $self
 Args    :

=cut
override 'write' => sub {
    my ($self,$complex,$names) = @_;
    $names ||= [$complex->names];
    my $strfh = $self->fh;

    my @alphabet = ('A' .. 'Z');
    my @chains = @alphabet[0..@$names];
    # Unique topology identifier: (i.e. connectivity, not templates used)
    my @iactions = values %{$complex->{interaction}};
    # Sort the nodes in a single edge. 
    my @edges = map { join(',', sort($_->nodes)) } @iactions;
    # Then sort over all these edge labels
    my $topology = join(';', sort(@edges));

    print $strfh "\% Components: ", join(" ", @$names), "\n";
    print $strfh "\% Chains: ", join(" ", @chains), "\n";
    print $strfh "\% Topology: $topology\n";
    print $strfh "\% Templates:\n";
    foreach my $iaction (sort @iactions) {
        print $strfh "\% Template: ", $iaction->ascsv, "\n";
    }
    print $strfh "\n";

    # Print all Domain objects (STAMP format)
    my $chainid = 0;
    foreach my $key (@$names) {
        my $dom = $complex->model($key);
        print $strfh "\% CHAIN ", $chains[$chainid++], " $key\n";
        $self->SUPER::write($dom);
    }
    print $strfh "\n";
    return $self;
};

################################################################################
__PACKAGE__->meta->make_immutable;
1;
