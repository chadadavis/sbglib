#!/usr/bin/env perl

=head1 NAME

SBG::ComplexIO - Reads L<SBG::Complex>s using L<SBG::DomainIO>

=head1 SYNOPSIS

 use SBG::ComplexIO;


=head1 DESCRIPTION



=SEE ALSO

L<SBG::Complex> , L<SBG::DomainIO> , L<SBG::IO>

=cut

package SBG::ComplexIO;
use SBG::Root -Base;
use base qw(SBG::IO);

use IO::String;

use SBG::Complex;
use SBG::DomainIO;
use SBG::CofM;
use SBG::Transform;


################################################################################

sub new () {
    my $class = shift;
    # Delegate to parent class
    my $self = new SBG::IO(@_);
    return unless $self;
    # And add our ISA spec
    bless $self, $class;
    return $self;
} # new


sub read {
    my $domio = new SBG::DomainIO(-fh=>$self->fh);
    my $dom;
    my $complex = new SBG::Complex();
    while ($dom = $domio->read) {
        # Get any centre-of-mass
        my $cdom = SBG::CofM::cofm($dom);
        # Update it:
        # TODO DES
        # Apply saved transformation to native CofM point
        $cdom->transform($dom->transformation);
        # Add Dom to complex
        $complex->add($cdom);
    }
    return $complex;
}

# Returns the string that was printed to the file
# Add a newline by default as well
sub write {
    my $complex = shift;
    my $str;
    my $strfh = new IO::String($str);

    my @alphabet = ('A' .. 'Z');
    my @names = $complex->names;
    my @chains = @alphabet[0..@names];
    # Unique topology identifier: (i.e. connectivity, not templates used)
    my @iactions = values %{$complex->{iaction}};
    # Sort the nodes in a single edge. 
    my @edges = map { join(',', sort($_->nodes)) } @iactions;
    # Then sort over all these edge labels
    my $topology = join(';', sort(@edges));

    print $strfh "\% Components: ", join(" ", @names), "\n";
    print $strfh "\% Chains: ", join(" ", @chains), "\n";
    print $strfh "\% Topology: $topology\n";
    print $strfh "\% Templates:\n";
    foreach my $iaction (sort @iactions) {
        print $strfh "\% ", $iaction->regurgitate, "\n";
    }
    print $strfh "\n";

    # Print all Domain objects (STAMP format)
    my $domio = new SBG::DomainIO(-fh=>$strfh);
    my $chainid = 0;
    foreach my $key (@names) {
        my $dom = $complex->comp($key);
        print $strfh "\% CHAIN ", $chains[$chainid++], " $key\n";
        $domio->write($dom,-id=>'stampid');
    }

    print $strfh "\n";
    my $fh = $self->fh;
    print $fh $str if $fh;
    return $str;

} # write

################################################################################

1;
