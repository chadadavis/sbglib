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

# Trying to avoid cach corruption with additional locking ...
use File::NFSLock;
use Fcntl qw/LOCK_EX LOCK_NB/;

use SBG::U::Log qw/log/;

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

    my $base = File::Spec->tmpdir;
    $base = $ENV{CACHEDIR} if -d $ENV{CACHEDIR} && -w $ENV{CACHEDIR};
    my $arch = `uname -m`;
    chomp $arch;
    my $cachedir = "${base}/${name}_${arch}";

    my $lock;
    if (wantarray) {
        $lock = File::NFSLock->new("${cachedir}.lock",LOCK_EX,60,5*60);
        log()->trace("Locked: $cachedir");
    }

    unless (defined $cache_hash{$name}) {
        $cache_hash{$name} = Cache::File->new(
            cache_root => $cachedir,
            lock_level => Cache::File::LOCK_NFS(),
            default_expires => '2 w',
            );
    }

    return wantarray ? ($cache_hash{$name}, $lock) : $cache_hash{$name};

}


################################################################################
1;
__END__


