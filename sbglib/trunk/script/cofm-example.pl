#!/usr/bin/env perl
use Modern::Perl;
use PDL;

# https://code.google.com/p/sbglib/source/browse/
use SBG::Domain::Sphere;
use SBG::DomainIO::cofm;

# For each assembly that has some $label;
my $pdbid = '1e79';
my $assembly = '2';
my $label = "$pdbid-$assembly";
my $file = "$ENV{'DS'}/cofm-classes/$label.cofm";
my $output = SBG::DomainIO::cofm->new(file=>">$file");

# For each fragment in an assembly:

# See SBG::DomainI for all the fields
# https://code.google.com/p/sbglib/source/browse/sbglib/trunk/lib/SBG/DomainI.pm
my $fragment = SBG::Domain::Sphere->new(
    pdbid=>$pdbid,
    assembly=>$assembly,                      # Biounity assembly (for unique label)
    model=>'4',                               # In case multiple labels
    descriptor=>'A 34 _ to A 566 B',          # STAMP format
    classification=>'class535',               # Cluster ID / SCOP ID
    coords=>pdl [[ 33.626,66.662,96.626, 1]], # homogenous coords, end with 1
    radius=>54.5,                             # Rg (or Rmax)
    );

$output->write($fragment);
$output->close;

# Read it back in:
my $input=SBG::Domain::cofm->new(file=>$file);
my @doms;
while (my $dom = $input->read) {
    push @doms, $dom;
}
my $dom = $doms[0];
# This is a PDL (maybe one point, maybe seven).
print $dom->coords;
# If the coords have been transformed, this is the transformation matrix;
print $dom->transformation if $dom->transformation->has_matrix;

