#!/usr/bin/env perl
package Test::SBG::Cache;
use base qw(Test::SBG);
use Test::SBG::Tools;

use SBG::Debug qw(debug);
use Scalar::Util qw(refaddr);

use SBG::Domain;
use SBG::Cache qw(cache);


sub basic : Tests {
    my $cache = cache(namespace=>'Test-SBG-Domain');
    my $dom1 = SBG::Domain->new(pdbid => '2br2', descriptor => 'CHAIN A');
    $cache->set('thekey2', $dom1);
    my $dom2 = $cache->get('thekey2');
    is $dom2, $dom1;
}

sub cache_cache : Tests {
    my $prev_mode = debug();
    debug(0);
    my $cache_a = cache;
    my $cache_b = cache;
    is refaddr($cache_a), refaddr($cache_b);
    # Reset
    debug($prev_mode);
}

sub namespace : Tests {
    my $cache = cache;
    my $name = (caller(0))[3];
    $name =~ s/::/-/g;
    is $cache->namespace, $name
        or diag $cache->namespace;
}

sub root_dir : Tests {
    my $prev_mode = debug();
    debug(0);
    my $cache = cache();
    # May not necessarily exist until written to:
    $cache->set('key', 'value');
    ok -d $cache->root_dir
        or diag $cache->root_dir;
    ok -w $cache->root_dir
        or diag $cache->root_dir;
    debug($prev_mode);
}

sub debug_mode : Tests {
    my $prev_mode = debug();
    debug(1);
    my $cache = cache();
    $cache->set('key', 5);
    isnt $cache->get('key'), 5;
    # Reset
    debug($prev_mode);
}

sub pass_through_options_override_defaults : Tests {
    my $cache = cache(expires_in => 666);
    is $cache->{expires_in}, 666;
}

sub read_persistent : Tests {
    my ($self)= @_;
    # Read from the static cache distributed with this test
    my $dir = $self->{test_data};
    my $cache = cache(root_dir => "$dir", namespace => 'test_cache');
    is $cache->get('test_key'), 'test_value';
}


sub arch_specific : Tests {
    my $cache1 = cache();
    my $cache2 = cache(arch_specific=>1);
    $cache2->set('key', 'value');
    isnt $cache1->get('key'), $cache2->get('key');
}
