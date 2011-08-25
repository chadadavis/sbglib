#!/usr/bin/env perl
use Modern::Perl;
use PDL;

# https://code.google.com/p/sbglib/source/browse/
use SBG::Domain::Sphere;
use SBG::DomainIO::cofm;

# For each assembly that has some $label;
my $pdbid = '1e7p';
my $assembly = '2';
my $model = '1';
my $label = "$pdbid-$assembly";
my $file = "$ENV{DS}/cofm-classes/$label.cofm";
my $output = SBG::DomainIO::cofm->new(
    file=>">$file", renumber_chains=>1, verbose=>1);

# For each fragment in an assembly:

# See SBG::DomainI for all the fields
# https://code.google.com/p/sbglib/source/browse/sbglib/trunk/lib/SBG/DomainI.pm
my $fragment = SBG::Domain::Sphere->new(
    pdbid=>$pdbid,
    assembly=>$assembly,                      # Biounity assembly (for unique label)
    model=>$model,                               # In case multiple labels, default 1
    descriptor=>'G 10 _ to G 107 _',          # STAMP format
    classification=>'class535',               # Cluster ID / SCOP ID
    center=>pdl([ 33.626,66.662,96.626, 1]),# homogenous coords, end with 1
    # Or, if you have all the coordinates
#    coords=>pdl(
#        [0,0,0, 1],             # center
#        [5,0,0, 1],[-5,0,0, 1], # X+, X-
#        [0,5,0, 1],[0,-5,0, 1], # Y+, Y-
#        [0,0,5, 1],[0,0,-5, 1], # Z+, Z-
#        ),
    radius=>54.5,                             # Rg (or Rmax)
    );

$output->write($fragment);
$output->close;

# Read it back in:
my $input=SBG::DomainIO::cofm->new(file=>$file);
my @doms;
while (my $dom = $input->read) {
    push @doms, $dom;
}
my $dom = $doms[0];
# This is a PDL (maybe one point, maybe seven).
print $dom->coords;
# If the coords have been transformed, this is the transformation matrix;
print $dom->transformation if $dom->transformation->has_matrix;

