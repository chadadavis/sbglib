#!/usr/bin/env perl

use Test::More 'no_plan';
use strict;
use warnings;

use FindBin qw/$Bin/;
use lib "$Bin/../../lib/";

use SBG::SCOP qw(lca equiv);

# my @strings = qw(a.2.4.1-2  a.2.4.1-1);
my @strings = qw(a.2.4.1-2  a.2.4.1-1);
is(lca(@strings), 'a.2.4.1', 'lca()');
ok(equiv(@strings,4), 'equiv()');
ok(! equiv(@strings,5), 'not equiv()');


__END__
