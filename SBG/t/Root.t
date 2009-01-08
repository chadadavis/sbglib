#!/usr/bin/env perl

# Re-enable logging

use Test::More 'no_plan';

use SBG::Root -base, -XXX;

ok(defined $installdir, "Installation directory: $installdir");
ok(defined $config, "Ini \$config hash");
ok(defined \YYY, "Spiffy's YYY debugging facility");

ok(defined $logger, "Log4perl \$logger");
ok($logger->debug("Test log message"), "Logging works");
ok($logger->error("Test error message"), "Error message works");

my %h = ( -thing => 2, -stuff => 3 );
SBG::Root::_undash(%h);
is($h{'thing'}, 2, "_undash on hash keys");


__END__
