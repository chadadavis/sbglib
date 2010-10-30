#!/usr/bin/env perl

package Test::SBG::U::Object;
# Inheritance
use base qw/Test::SBG/;
# Just 'use' it to import all the testing functions and symbols 
use Test::SBG;

use SBG::U::Object qw/load_object/;

# If the startup test(s) fail, the other tests are skipped
sub load_network : Tests(startup=>2) {
	my $file = catfile($test_data, '1a4e.network');
	ok(-r $file, 'Found Storable object');
	$x = load_object($file);
	ok(defined $x, 'Loaded Storable object');
}

sub autoloaded_class : Tests {
	ok($INC{'SBG/Network.pm'}); 
}

1;
__END__

