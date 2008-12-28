#!/usr/bin/env perl

use Test::More 'no_plan';

use EMBL::Root -base, -XXX;

ok(defined $config, "Ini \$config hash");
ok(defined $logger, "Log4perl \$logger");
ok(defined \$logger->debug, "Log4perl \$logger->debug");
ok(defined \YYY, "Spiffy's YYY debugging facility");
ok(defined \_rearrange, "Bio::Root::Root's _rearrange");


__END__
