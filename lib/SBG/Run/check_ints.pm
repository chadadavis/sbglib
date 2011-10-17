#!/usr/bin/env perl

=head1 NAME

SBG::Run::check_ints - B<check_ints> wrapper for finding residue contacts

=head1 SYNOPSIS

 use SBG::Run::check_ints qw/check_ints/;

 my @contacts = check_ints([ $dom1, $dom2 ]);
 my @contacts = check_ints([ $dom1, $dom2 ], N => 5, min_dist => 10);

=head1 DESCRIPTION


=head1 SEE ALSO

B<check_ints> is a program in the STAMP package.

=head1 TODO

=cut

package SBG::Run::check_ints;
use strict;
use warnings;
use base qw/Exporter/;
our @EXPORT_OK = qw/check_ints/;

use Text::ParseWords qw/quotewords/;
use PDL::Lite;
use PDL::Core qw/pdl/;
use Log::Any qw/$log/;
use File::Temp qw/tempfile/;

use SBG::DomainIO::stamp;
use SBG::Cache qw/cache/;


sub check_ints {
    my ($doms, %opts) = @_;
    my @doms = @$doms;
    # Don't cache if they've been transformed
    if (grep { $_->transformation->has_matrix } @doms) {
        return _run($doms, %opts);
    }

    my $cache = cache();
    # Order could be signficant
    my $key = "@doms";
    my $contacts = $cache->get($key);
    if (defined $contacts) {
        # [] is the marker for a negative cache entry
        return if ref($contacts) eq 'ARRAY';
        return $contacts;
    }

    # Cache miss, run external program
    $contacts = _run($doms, %opts);
    unless ($contacts) {
        # Failed, set negative cache entry
        $cache->set($key, []);
        return;
    }

    # Success, positive cache
    $cache->set($key, $contacts);
    return $contacts;
}


sub _run {
    my ($doms) = @_;
    my @doms = @$doms;
    # Get dom into a stamp-formatted file (don't write transformation)
    my $io = SBG::DomainIO::stamp->new(tempfile => 1);
    $io->write(@doms);
    my $path = $io->file;
    $io->close;

    # use -rv to get the actual residue-residue contacts
    my $res = `check_ints -f $path`;
    chomp $res;
    my @res = split ' ', $res;
    return $res[2];
}

1;
