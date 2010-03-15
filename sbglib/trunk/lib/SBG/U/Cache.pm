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
use File::Spec;

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
            l1_cache => { driver=>'Memory', global=>1, cache_size=>'50m' }
            );
    }

    return $cache_hash{$name};

}


################################################################################
1;
__END__


