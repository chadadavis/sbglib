#!/usr/bin/env perl

=head1 NAME

SBG::U::Cache -

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SEE ALSO

L<Cache::File>

=cut

################################################################################

package SBG::U::Cache;
use base qw/Exporter/;
our @EXPORT_OK = qw/cache cache_get cache_set/;

use strict;
use warnings;
use File::Spec;
use Log::Any qw/$log/;
use CHI;

# Cache cache  ;-)
our %cache_hash;


################################################################################
=head2 cache

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub cache {
    my ($name) = @_;
    our %cache_hash;
    our $arch;
    unless (defined $arch) { $arch = `uname -m`; chomp $arch; }

    my $base = File::Spec->tmpdir;
    $base = $ENV{CACHEDIR} if -d $ENV{CACHEDIR} && -w $ENV{CACHEDIR};
    my $cachedir = "${base}/${name}_${arch}";

    unless (defined $cache_hash{$name}) {
        $cache_hash{$name} = CHI->new(
            namespace => "${name}_${arch}",
            driver=>'File', 
#             driver=>'Null', 
            root_dir   => $base,
            expires_in => '2 weeks',
            cache_size => '100m',
            l1_cache => { driver=>'Memory', global=>1, cache_size=>'50m' }
            );
    }

    return $cache_hash{$name};

}


################################################################################
=head2 cache_get

 Function: 
 Example : 
 Returns : Re-retrieved object from cache
 Args    : [] implies negative caching

Cache claims to even work between concurrent processes!

=cut
sub cache_get {
    my ($cachename, $key) = @_;
    my ($cache,$lock) = cache($cachename);

    if (my $data = $cache->get($key)) {

        my $status;
        # (NB [] means negative cache)
        if (ref($data) eq 'ARRAY') {
            $status = 'negative';
        } else {
            $status = 'positive';
        }
        $log->debug("$cachename: $status get:", $key);
        return $data;
    } 
    $log->info("$cachename: miss:", $key);
    return;

} # cache_get


=head2 cache_set

 Function: 
 Example : 
 Returns : Re-retrieved object from cache
 Args    : [] implies negative caching

Cache claims to even work between concurrent processes!

=cut
sub cache_set {
    my ($cachename, $key, $data) = @_;
    my ($cache,$lock) = cache($cachename);

    my $status;
    # (NB [] means negative cache)
    if (ref($data) eq 'ARRAY') {
        $status = 'negative';
    } else {
        $status = 'positive';
    }

    $log->debug("$cachename: $status set:", $key);
    $log->debug(ref($data), "\n", $data);
    
    $cache->set($key, $data);

    # Verification;
    return $cache->is_valid($key);

} # cache_set


################################################################################
1;
__END__


