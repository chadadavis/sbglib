#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'SBG' );
}

diag( "Testing SBG $SBG::VERSION, Perl $], $^X" );
