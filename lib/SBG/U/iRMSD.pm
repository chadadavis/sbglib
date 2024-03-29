#!/usr/bin/env perl

=head1 NAME

SBG::U::RMSD - 

=head1 SYNOPSIS

use SBG::U::iRMSD;


=head1 DESCRIPTION

=head1 REQUIRES


=head1 AUTHOR

Chad Davis <chad.davis@embl.de>

=head1 SEE ALSO

L<SBG::U::RMSD> L<SBG::Superposition::Cache> L<SBG::STAMP>

=cut

package SBG::U::iRMSD;
use strict;
use warnings;
require Exporter;
our @ISA = qw(Exporter);

# Manually exported symbols
our @EXPORT_OK = qw(irmsd);

use Moose::Autobox;
use PDL::Lite;
use PDL::Core qw/pdl/;

use SBG::U::RMSD qw/rmsd/;
use SBG::Superposition::Cache qw/superposition/;
use SBG::Run::cofm qw/cofm/;

=head2 irmsd

 Function: 
 Example : 
 Returns : 
 Args    : 

    # TODO BUG What if transformations already present
    # And what if they're from different PDB IDs (same question)

=cut

sub irmsd {
    my ($doms1, $doms2) = @_;

    # NB these superpositions are unidirectional (always from 1 to 2)
    # Only difference, relative to A or B component of interaction

    my $supera = superposition($doms1->[0], $doms2->[0]);
    my $superb = superposition($doms1->[1], $doms2->[1]);
    return unless defined($supera) && defined($superb);

    # Define crosshairs, in frame of reference of doms1 only
    my $coordsa = _irmsd_rel($doms1, $supera);
    my $coordsb = _irmsd_rel($doms1, $superb);

    # RMSD between two sets of 14 points (two crosshairs) each
    my $irmsd = rmsd($coordsa, $coordsb);
    return $irmsd;
}    # irmsd

# Get coordinates of reference domains relative to given transformation
sub _irmsd_rel {
    my ($origdoms, $superp) = @_;

    # TODO BUG
    # This step will not work if you 'map' @$origdoms to $spheres
    # May be a bug in garbage collection of weak references.
    # This works as long as objects are created explicitly
    my $spheres = [];
    foreach my $d (@$origdoms) {
        $spheres->push(SBG::Run::cofm::cofm($d));
    }

    # Apply superposition to each of the domains
    $spheres->map(sub { $superp->apply($_) });

    # Coordinates of two crosshairs using transformation
    # TODO DES clump needs to be in a DomSetI
    my $coords = $spheres->map(sub { $_->coords });

    # Convert to single matrix
    $coords = pdl($coords)->clump(1, 2);

    return $coords;
}

###############################################################################

1;

__END__
