#!/usr/bin/env perl

package Test::SBG::U::Object;
# Inheritance
use base qw/Test::SBG/;
use Test::SBG;

	
# If the startup test(s) fail, the other tests are skipped
# Thi is not the case for 'setup' methods, however (continues on failure)
sub load_network : Tests(4) {
	my $self = shift;
	my $file = file($self->{test_data}, '1a4e.network');
	ok(-r $file, 'Found Storable object');
	$x = SBG::U::Object::load_object($file);
	ok(defined $x, 'Loaded Storable object');
	isa_ok($x, 'SBG::Network', 'Correct class');
    ok($INC{'SBG/Network.pm'}, 'Class auto-loaded');
}


1;