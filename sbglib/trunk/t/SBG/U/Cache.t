#!/usr/bin/env perl

use Test::More 'no_plan';
use SBG::U::Test 'float_is';
use Carp;
use Data::Dumper;
use Data::Dump qw/dump/;
use File::Temp qw/tempfile/;

use SBG::U::Log qw/log/;
$SIG{__DIE__} = \&confess;
my $DEBUG;
$DEBUG = 1;
log()->init('TRACE') if $DEBUG;
$File::Temp::KEEP_ALL = $DEBUG;


use SBG::Seq;
use SBG::Domain;
# use SBG::U::Cache qw/cache/;

use CHI;

my $cache = CHI->new(
    namespace => 'blah',
#     driver=>'Memory', 
#     global => 1,
    driver=>'File', 
    root_dir   => '/tmp',
#     l1_cache => { driver=>'Memory', global=>1},
    l1_cache => { driver=>'Memory', global=>1, cache_size=>'50m' }
);


# my $cache = CHI->new(driver=>'Memory');
# my $cache = CHI->new(driver=>'FastMmap');


my $dom1 = SBG::Domain->new(pdbid=>'2br2', descriptor=>'CHAIN A');
for (my $i = 0; $i < 100_000; $i++) {
    my $dom2;
    unless ($dom2 = $cache->get('thekey2')) {
        $cache->set("thekey2", $dom1);
        $dom2 = $cache->get('thekey2'); 
    }
die unless $dom2 == $dom1;

# is($dom2, $dom1, "cache get()");
# print dump $dom2;
}



__END__



my $cache = cache('test');

my $dom1 = SBG::Domain->new(pdbid=>'2br2', descriptor=>'CHAIN A');
$cache->set("thekey2", $dom1);



my $dom2 = $cache->get('thekey2'); 
is($dom2, $dom1, "cache_get()");

print dump $dom2;

__END__

ok(SBG::Domain->cache_clear("thekey2"), 'cache_clear()');

ok(! SBG::Domain->cache_get("thekey2"), "cache_clear()");







