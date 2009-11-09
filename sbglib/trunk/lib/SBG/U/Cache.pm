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
our @EXPORT_OK = qw(cache);

use strict;
use warnings;
use Cache::File;
use File::Spec;

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

    our $cache_hash;
    return $cache_hash{$name} if defined $cache_hash{$name};

    my $base = File::Spec->tmpdir;
    $base = $ENV{CACHEDIR} if -d $ENV{CACHEDIR} && -w $ENV{CACHEDIR};

    my $arch = `uname -m`;
    chomp $arch;
    my $cachedir = "${base}/${name}_${arch}";

    $cache_hash{$name} = Cache::File->new(
        cache_root => $cachedir,
        lock_level => Cache::File::LOCK_NFS(),
        default_expires => '2 w',
        );
    return $cache_hash{$name};
}


################################################################################
1;
__END__


