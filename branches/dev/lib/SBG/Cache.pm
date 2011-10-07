#!/usr/bin/env perl

=head1 NAME

SBG::Cache - Simple wrapper for L<CHI> caching framework

=head1 SYNOPSIS

Get a handle to a cache, by name:

 my $cache = cache();
 my $cache = cache(namespace => 'myapplication');
 my $cache = cache(namespace => 'myapplication_x86_64');
 my $cache = cache(root_dir=>'/my/cache/dir');

The cache name will default to the name of the calling subroutine, e.g.

 package My::Module;
 use SBG::Cache qw(cache);
 sub work_it {
     my $cache = cache()
     my $obj = $cache->get('the-key');
     if (! defined $obj) {
         $obj = _expensive_lookup_or_computation('the-key');
         $cache->set('the-key', $obj);
     }
 }

=head1 DESCRIPTION

The cache is a L<CHI> and you can do anything with it that you can do with
L<CHI>. This wrapper just provides the default options for a multi-level cache
with an in-memory cache in front of an on-disk cache.

 driver    => 'File',
 cache_size => '1024m',
 l1_cache => {
     driver => 'Memory', 
     global => 1, 
     cache_size => '100m',
 }

The default namespace will be the name of the calling subroutine, prefixed
with the name of the module or file name. If another request is made with the
same namespace, you will get the same cache handle. E.g. with no parameters,
any two calls from the same subroutine will get the same cache handle,
otherwise just provide your own namespace. Also, to share a cache between
functions, you will need to explicitly provide a namespace.

The default <code>root_dir</code> will be C<$HOME/.cache/> which you can
override by setting the $CACHEDIR environment variable.

Beware that some data should not be shared between architectures, depending on
the nature of the data. In that case you should add the machine architecture
to the namespace, using something like:

 my $cache = cache(arch_specific=>1)

Caching will be disabled when in debug mode. See L<SBG::Debug> .

If you want to be able to do negative caching, i.e. remember when something
did not work, so that you do not repeat it, just come up with some sentinel
value that will otherwise never occur. I use an empty ArrayRef, i.e. [] So,
when the value returned by the cache is [] then it means I already tried and
failed and do not need to try it again. But, you need to check for your
sentinel value yourself.

Cache claims to even work between concurrent processes!

=head1 SEE ALSO

=over 4

=item * L<CHI>

=back

=cut

package SBG::Cache;
use strict;
use warnings;

use base qw(Exporter);
our @EXPORT_OK = qw(cache);

use CHI;
use Config;

use SBG::Debug;
#use Devel::Comments;

my $arch = $Config{myarchname};


=head2 cache


=cut 

# A cache cache  ;-)
my %cache_cache;

sub cache {
    my (%opts) = @_;
    if (SBG::Debug::debug) {
        $opts{driver} ||= 'Null';
        return CHI->new(%opts);
    } 
    $opts{namespace} ||= namespace();
    $opts{root_dir}  ||= _build_root_dir();
    if ($opts{arch_specific}) {
        $opts{namespace} .= '_' . $arch;
    }
    if (! defined $cache_cache{$opts{namespace}}) {
        my $chi = CHI->new(
            driver    => 'File',
            cache_size => '1024m',
            l1_cache => {
                driver => 'Memory', 
                global => 1, 
                cache_size => '100m',
            },
            # Override default with any explicit options
            %opts,
        );
        $cache_cache{$opts{namespace}} = $chi;
    }
    return $cache_cache{$opts{namespace}};
}

sub _build_root_dir {
    my $base = $ENV{CACHEDIR} || "$ENV{HOME}/.cache";
    mkdir $base if $base;
    if (! -d $base || ! -w $base) {
        die "Cache directory ($base) non-existant / not-writable";
    }
    return $base;
}

# Filesystem-friendly name for the module/script that called us
sub namespace {
    my ($level) = @_;
    $level = 1 unless defined $level;
    # Strip of this function by incrementing level
    $level++;
    my ($pkg, $file, undef, $sub) = caller($level);
    # $sub be something like:
    # MyModule::my_function, main::my_function, or undef
    $sub =~ s/::/-/g;
    # File's basename, plus extension (all the non-slashes at the end)
    ($file) = $file =~ m|([^/]+)$|;
    # If sub was in 'main' pkg, or not in a sub at all, prepend file name
    $sub =~ s/^main/$file/;
    if (! defined $pkg) {
        $sub = $file . '-' . $pkg;
    }
    return $sub;
}

1;



