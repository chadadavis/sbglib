#!/usr/bin/env perl

use Test::More 'no_plan';

use SBG::Root -base, -XXX;

ok(defined $config, "Ini \$config hash");
ok(defined $logger, "Log4perl \$logger");
ok(defined \$logger->debug, "Log4perl \$logger->debug");
ok(defined \YYY, "Spiffy's YYY debugging facility");
# ok(defined \_rearrange, "Bio::Root::Root's _rearrange");

my %h = ( -thing => 2, -stuff => 3 );
SBG::Root::_undash(%h);
is($h{'thing'}, 2, "_undash on hash keys");


__END__
