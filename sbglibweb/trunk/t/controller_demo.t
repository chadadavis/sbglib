use strict;
use warnings;
use Test::More;

BEGIN { use_ok 'Catalyst::Test', 'SBG::ACA' }
BEGIN { use_ok 'SBG::ACA::Controller::demo' }

ok( request('/demo')->is_success, 'Request should succeed' );
done_testing();
