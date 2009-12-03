
use Test::More 'no_plan';

use SBG::U::List qw/argmin argmax which/;

# Single element
my ($elem, $max) = argmax { $_ } (5);
is($elem, 5);
is($max, 5);

# Multiple
my ($elem, $max) = argmax { $_ } (5,2,6,3);
is($elem, 6);
is($max, 6);

# With objects
my ($elem, $max) = argmax { $_->{val} } ({val=>5},{val=>2},{val=>6},{val=>3});
is_deeply($elem,{val=>6});
is($max,6);

# Scalar context
my $elem = argmax { $_->{val} } ({val=>5},{val=>2},{val=>6},{val=>3});
is_deeply($elem,{val=>6});

# Min
my $elem = argmin { $_->{val} } ({val=>5},{val=>2},{val=>6},{val=>3});
is_deeply($elem,{val=>2});


