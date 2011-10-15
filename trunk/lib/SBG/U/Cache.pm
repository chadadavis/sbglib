#!/usr/bin/env perl

=head1 NAME

SBG::U::Cache - Simple wrapper for L<CHI> caching framework

=head1 DESCRIPTION

This module is now deprecated in favor of L<SBG::Cache>

Caching will be disabled when in debug mode. See L<SBG::Debug> .

Assumes that an empty ArrayRef (C<[]>) implies a negative cache hit.

Cache claims to even work between concurrent processes!

=head1 SEE ALSO

=over 4

=item * L<CHI>

=back

=cut

package SBG::U::Cache;
use strict;
use warnings;

use base qw/Exporter/;
our @EXPORT_OK = qw/cache cache_get cache_set/;

use File::Spec;
use Log::Any qw/$log/;
use CHI;
use Carp qw(cluck);
use SBG::Debug;

BEGIN {
    # Provide a backtrace because the caller is more than 1 level away
    cluck __PACKAGE__ , ' is deprecated in favor of SBG::Cache';
}

=head2 cache

Get a handle to cache, by name:

 my $cache = cache('myapplication');

You generally don't need to use this directly. Just pass the name to
C<cache_get> and C<cache_set> .

=cut

# Cache cache  ;-)
my %cache_hash;
my $arch;

sub cache {
    my ($name) = @_;

    unless (defined $arch) { $arch = `uname -m`; chomp $arch; }

    my $base = $ENV{CACHEDIR};
    mkdir $base if $base;
    $base = File::Spec->tmpdir unless defined($base) && -d $base && -w $base;
    my $cachedir = "${base}/${name}_${arch}";

    unless (defined $cache_hash{$name}) {
        $cache_hash{$name} = CHI->new(
            namespace => "${name}_${arch}",
            driver    => 'File',

            #             driver=>'Null',
            root_dir   => $base,
            expires_in => '2 weeks',
            cache_size => '500m',
            l1_cache =>
                { driver => 'Memory', global => 1, cache_size => '50m' }
        );
        $log->info("cachedir: $cachedir");
    }

    return $cache_hash{$name};

}

=head2 cache_get

Fetch item from cache:

 my $obj = cache_get('myapplication', 'some_lookup_key');

=cut

sub cache_get {
    my ($cachename, $key)  = @_;
    if (SBG::Debug::debug) { return; }

    my ($cache, $lock) = cache($cachename);

    if (my $data = $cache->get($key)) {

        my $status;

        # (NB [] means negative cache)
        if (ref($data) eq 'ARRAY') {
            $status = 'negative';
        }
        else {
            $status = 'positive';
        }
        $log->debug("$cachename: $status get:", $key);
        return $data;
    }
    $log->info("$cachename: miss:", $key);
    return;

}    # cache_get

=head2 cache_set

Set a cache key:
 
 cache_set('myapplication', 'some_key_id', $the_thing);
 # $the_thing will be serialized

=cut

sub cache_set {
    my ($cachename, $key, $data) = @_;

    if (SBG::Debug::debug) { return; }

    my ($cache, $lock) = cache($cachename);

    my $status;

    # (NB [] means negative cache)
    if (ref($data) eq 'ARRAY') {
        $status = 'negative';
    }
    else {
        $status = 'positive';
    }

    $log->debug("$cachename: $status set:", $key);
    $log->debug(ref($data), "\n", $data);

    $cache->set($key, $data);

    # Verification;
    return $cache->is_valid($key);

}    # cache_set

1;
__END__


