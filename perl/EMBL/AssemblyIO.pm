#!/usr/bin/env perl

# TODO POD

# TODO use Spiffy

package EMBL::AssemblyIO;

use Spiffy -Base, -XXX;
field 'fh';

use lib "..";
use EMBL::Assembly;
use EMBL::DomIO;

################################################################################

# TODO DOC
sub new() {
    my $self = {};
    bless $self, shift;
    my $fh = shift;
    $self->{fh} = $fh;
    return $self;
}


sub next_assembly {
    my $domio = new EMBL::DomIO($self->fh);
    my $dom;
    my $assem = new EMBL::Assembly();
    while ($dom = $domio->next_dom) {
        # Add Dom to Assembly
        print STDERR "Dom:", $dom->label, "\n";
        $assem->cofm($dom->label, $dom);
    }
    return $assem;
}

sub write {
    my $assem = shift;
    # TODO DES needs to be in constructor
    my $fh = shift;

    print STDERR "AssemblyIO::write\n";

    # Unique topology identifier:
    # For each edge, component names sorted, then edges sorted
    my @ikeys = keys %{$assem->{interaction}};
    my @iactions = map { $assem->{graph}->get_interaction_by_id($_) } @ikeys;
    my @edges = map { join(',', sort($_->nodes)) } @iactions;
    my $topology = join(';', sort(@edges));

    print $fh "\% Topology: $topology\n";
    print $fh "\% Templates: ", $assem->stringify(), "\n";
    print $fh "\n";

    # TODO PROB should be OK to share the fh, right?
    my $domio = new EMBL::DomainIO(-fh=>$fh);

    # Print all CofM objects (STAMP format)
    # STAMP will number the chains alphabetically in the final output
    my $chainid = ord 'A';
    # $key is the component's label
    foreach my $key (sort keys %{$assem->{cofm}}) {
        # id is the PDB ID of the template segment
        print STDERR "\tsaving: $key ", $assem->cofm($key)->id(), "\n";

        print $fh "\% CHAIN ", chr($chainid++), " $key\n";

        # This uses the cumulative transform, maintained by CofM itself
        my $cofm = $assem->cofm($key);
        $domio->write($cofm);
    }
    print $fh "\n";
    return 1;
} # save

################################################################################

1;
