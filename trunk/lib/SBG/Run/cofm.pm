#!/usr/bin/env perl

=head1 NAME

SBG::Run::cofm - Wrapper for running B<cofm> (centre-of-mass)


=head1 SYNOPSIS

 use SBG::Run::cofm qw/cofm/;

 my $dom = SBG::DomainI->new(pdbid=>'2nn6', descriptor=>'A 13 _ to A 331 _');
 my $centroid = cofm($dom);

 my $dom = SBG::DomainI->new(pdbid=>'2nn6', descriptor=>'A 13 _ to A 331 _');

 $hashref = cofm('2nn6','A 13 _ to A 331 _');
 $hashref = cofm('2nn6','CHAIN A CHAIN B');


=head1 DESCRIPTION

Fetches center of mass, radius of gyration and maximum radius of the centre of
mass.

Returns a L<SBG::Domain::Sphere> instance, which represents a (very) globular domain, having only a center and a radius (of gyration)

=head1 SEE ALSO

B<cofm> is a program in the STAMP package.

L<SBG::U::DB::cofm> , L<SBG::Domain::Sphere>

=cut

package SBG::Run::cofm;
use strict;
use warnings;
use base qw/Exporter/;
our @EXPORT_OK = qw/cofm/;

use Text::ParseWords qw/quotewords/;
use PDL::Lite;
use PDL::Core qw/pdl/;
use Log::Any qw/$log/;
use Digest::MD5 qw/md5_base64/;
use File::Temp qw/tempfile/;

use SBG::Domain::Sphere;
use SBG::DomainIO::stamp;
use SBG::DomainIO::cofm;
use SBG::Cache qw/cache/;

# TODO DES OO (base on Bio::Tools::Run::Wrapper)
# cofm binary (should be in PATH)
my $cofm = 'cofm';


=head2 cofm

 Function: 
 Example : 
 Returns : a new L<SBG::Domain::Sphere>
 Args    : L<SBG::DomainI>

Original Domain is not modified

B<cofm> must be in your PATH, or defined in a B<config.ini> file

NB if the input L<SBG::DomainI> has a B<transformation>, this is not saved in
the newly created L<SBG::Domain::Sphere>

TODO option to use Rg or Rmax as the resulting radius

Uses parser from L<SBG::DomainIO::cofm>

=cut

sub cofm {
    my ($dom, %ops) = @_;

    my $cache = cache();
    my $key = _hash($dom);
    my $sphere;
    $sphere = $cache->get($key);
    if (defined $sphere) {

        # [] is the marker for a negative cache entry
        return if ref($sphere) eq 'ARRAY';
        return $sphere;
    }

    # Cache miss, run external program
    $sphere = _run($dom);
    unless ($sphere) {

        # cofm failed, set negative cache entry
        $cache->set($key, []);
        return;
    }

    # Success, positive cache
    $cache->set($key, $sphere);

    return $sphere;

}    # cofm

# Hash a DomainI, including any transformation coords
# Used to get a unique identifier to the cache
sub _hash {
    my ($dom)  = @_;
    my $domstr = "$dom";
    my $trans  = $dom->transformation;
    my $transstr = $trans ? md5_base64("$trans") : '';
    $domstr .= '(' . $transstr . ')' if $transstr;
    return $domstr;
}

=head2 _run

 Function: Computes centre-of-mass and radius of gyration of STAMP domain
 Example : 
 Returns : L<SBG::Domain::Sphere>
 Args    : L<SBG::DomainI>

=cut

sub _run {
    my ($dom) = @_;

    # Get dom into a stamp-formatted file
    my $io = SBG::DomainIO::stamp->new(tempfile => 1);
    $io->write($dom);
    my $path = $io->file;
    $io->close;

    # NB the -v option is necessary if you want the filename of the PDB file
    # TODO consider using Capture::Tiny or IPC::Cmd
    my (undef, $tempfile) = tempfile();
    my $cmd = "$cofm -f $path -v > $tempfile";
    unless (system($cmd) == 0) {
        $log->error("Failed:\n\t$cmd\n\t$!");
        return;
    }

    my $in = SBG::DomainIO::cofm->new(file => $tempfile);

    # Assumes a single domain
    my $sphere = $in->read;
    return $sphere;

}    # _run

1;
