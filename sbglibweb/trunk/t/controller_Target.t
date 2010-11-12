use strict;
use warnings;
use Test::More;

BEGIN { use_ok 'Catalyst::Test', 'acaweb' }
BEGIN { use_ok 'acaweb::Controller::Target' }

ok( request('/target')->is_success, 'Request should succeed' );
done_testing();
