#!/usr/bin/env perl

=head1 NAME

SBG::AssemblyIO - Reads L<SBG::Assembly>s using L<SBG::DomainIO>

=head1 SYNOPSIS

 use SBG::AssemblyIO;


=head1 DESCRIPTION



=SEE ALSO

L<SBG::Assembly> , L<SBG::DomainIO> , L<SBG::IO>

=cut

package SBG::AssemblyIO;
use SBG::Root -Base, -XXX;
use base qw(SBG::IO);

use IO::String;

use SBG::Assembly;
use SBG::DomainIO;


################################################################################

sub new () {
    my $class = shift;
    # Delegate to parent class
    my $self = new SBG::IO(@_);
    # And add our ISA spec
    bless $self, $class;
    return $self;
} # new


sub read {
    my $domio = new SBG::DomainIO(-fh=>$self->fh);
    my $dom;
    my $assem = new SBG::Assembly();
    while ($dom = $domio->read) {
        # Add Dom to Assembly
        $assem->comp($dom->stampid) = $dom;
    }
    return $assem;
}

# Returns the string that was printed to the file
# Add a newline by default as well
sub write {
    my $assem = shift;
    my $fh = $self->fh;
    my $str;
    my $strfh = new IO::String($str);

    # Unique topology identifier:
    # For each edge, component names sorted, then edges sorted
    my @ikeys = keys %{$assem->{iaction}};
    my @iactions = map { $assem->{graph}->get_interaction_by_id($_) } @ikeys;
    my @edges = map { join(',', sort($_->nodes)) } @iactions;
    my $topology = join(';', sort(@edges));

    print $strfh "\% Topology: $topology\n";
    print $strfh "\% Templates: ", $assem, "\n";
    print $strfh "\n";

    my $domio = new SBG::DomainIO(-fh=>$strfh);

    # Print all Domain objects (STAMP format)
    # STAMP will number the chains alphabetically in the final output
    my $chainid = ord 'A';
    # $key is the component's label
    foreach my $key (sort keys %{$assem->{comp}}) {
        # id is the PDB ID of the template segment
        print STDERR "\tsaving: $key ", $assem->comp($key)->pdbid(), "\n";
        print $strfh "\% CHAIN ", chr($chainid++), " $key\n";
        # This uses the cumulative transform, maintained by CofM itself
        my $comp = $assem->comp($key);
        $domio->write($comp);
    }
    print $strfh "\n";
    print $fh $str if $fh;
    return $str;

} # save

################################################################################

1;
