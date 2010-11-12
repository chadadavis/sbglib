use strict;
use warnings;
use Test::More;

BEGIN { use_ok 'Catalyst::Test', 'acaweb' }
BEGIN { use_ok 'acaweb::Controller::Experiment' }

ok( request('/experiment')->is_success, 'Request should succeed' );
done_testing();
