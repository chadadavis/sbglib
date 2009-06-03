#!/usr/bin/env perl

use Test::More 'no_plan';

use warnings;

use SBG::STAMP;
use SBG::Domain::CofM;
use SBG::Domain;
use SBG::CA::Assembler qw(linker);

TODO: {
    local $TODO = "Update test";
    ok(1);
}

__END__


# Similar to example in STAMP.t but use at least two chained superpositions
# Do not simply multiply twice, instead: chain them!

# Based on archael exosome (2br2: one ring: Chains DABEFC )
# 2 unique chains: A (and every 2nd), B (and every 2nd)
# Templates: D-A(and A-D), A-B(and B-A)

# link b<=>d or a<=>e or a<=>a or b<=>b
my @doms;
my @templates = (
    [new SBG::Domain(-label=>'2br2D-c1'), new SBG::Domain(-label=>'2br2A-c2')],
    [new SBG::Domain(-label=>'2br2A-c2'), new SBG::Domain(-label=>'2br2B-c3')],
    [new SBG::Domain(-label=>'2br2D-c3'), new SBG::Domain(-label=>'2br2A-c4')],
    [new SBG::Domain(-label=>'2br2A-c4'), new SBG::Domain(-label=>'2br2B-c5')],
    [new SBG::Domain(-label=>'2br2D-c5'), new SBG::Domain(-label=>'2br2A-c6')],
    );

my ($firstsrc, $firstdest) = @{shift @templates};
$firstsrc = SBG::CofM::cofm($firstsrc);
$firstdest = SBG::CofM::cofm($firstdest);
push @doms, $firstsrc, $firstdest;
my $ref = $firstdest;

foreach my $t (@templates) {
    my ($srcdom, $destdom) = @$t;
    $srcdom = SBG::CofM::cofm($srcdom);
    $destdom = SBG::CofM::cofm($destdom);
    $destdom = linker($ref, $srcdom, $destdom);
    push @doms, $destdom;
    $ref = $destdom;
}

# use File::Temp qw(tempfile);
# use SBG::DomainIO;
# my (undef, $domfile) = tempfile();
# my $io = new SBG::DomainIO(-file=>">$domfile");
# $io->write($_) for @doms;
# print "dom: $domfile\n";
my $pdbfile = transform(-doms=>\@doms);
ok($pdbfile, "transform() created a PDB file");
`rasmol $pdbfile` if $pdbfile;

__END__

