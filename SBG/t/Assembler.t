#!/usr/bin/env perl

use warnings;

use SBG::STAMP;
use SBG::CofM;
use SBG::Domain;
use SBG::Assembler qw(linker);

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
get_cofm($firstsrc);
get_cofm($firstdest);
push @doms, $firstsrc, $firstdest;
my $ref = $firstdest;

foreach my $t (@templates) {
    my ($srcdom, $destdom) = @$t;
    get_cofm($srcdom);
    get_cofm($destdom);
    linker($ref, $srcdom, $destdom);
    push @doms, $destdom;
    $ref = $destdom;
}

use File::Temp qw(tempfile);
use SBG::DomainIO;
my (undef, $domfile) = tempfile();
my $io = new SBG::DomainIO(-file=>">$domfile");
$io->write($_) for @doms;
print "dom: $domfile\n";
# my $pdbfile = transform(-doms=>[@doms]);
# print "pdb: $pdbfile\n";

__END__

