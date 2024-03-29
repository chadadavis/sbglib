#!/usr/bin/env perl

=head1 NAME

SBG::Run::pdbc - Wrapper for running B<pdbc> (to get entry/chain descriptions

=head1 SYNOPSIS

 use SBG::Run::pdbc qw/pdbc/;

 my $templates = '1g3nAC';
 my $pdbc = pdbc($templates);
 print 'Annotation for chain A : ', $pdbc->{chain}{A};
 print 'Annotation for whole complex : ', $pdbc->{header};
 
=head1 DESCRIPTION

Wrapper for 'pdbc' from the STAMP suite.

 http://code.google.com/p/bio-stamp/

=head1 SEE ALSO

L<SBG::DomainI>

=cut

package SBG::Run::pdbc;
use strict;
use warnings;
use base qw/Exporter/;
our @EXPORT_OK = qw/pdbc/;

use Moose::Autobox;
use Log::Any qw/$log/;

use SBG::Types qw/$pdb41/;
use SBG::Cache qw/cache/;

=head2 pdbc

 Function: 
 Example : 
 Returns : Hash
 Args    : L<SBG::DomainI>


B<pdbc> must be in your PATH

=cut

sub pdbc {
    my ($str) = @_;
    $log->debug($str);
    my $cache = cache();

    my ($pdb, $chains) = $str =~ /^(\d\w{3})(.*)?/;

    # Get struture for entire PDB entry, if not already fetched
    my $cached = $cache->get($pdb);
    if (! defined $cached) {
        $cached = _run($pdb);
        $cache->set($pdb, $cached);
    }
    return $cached unless $chains;

    # But only provide chain information for given chains
    my @chains = split '', $chains;

    # Copy
    my $subcomplex = {%$cached};

    # Remove an copied chains
    $subcomplex->{chain} = {};

    # Add only requested chains
    $subcomplex->{chain}{$_} = $cached->{chain}{$_} for @chains;
    return $subcomplex;

}    # pdbc

sub _run {
    my ($pdb,) = @_;
    open my $pdbcfh, '-|', "pdbc -d ${pdb}";

    #    open my $pdbcfh, "pdbc -d ${pdb} |";

    # Process header first
    my $header = _header($pdbcfh, $pdb);

    # Suck up other chains
    my %fields = _chains($pdbcfh);

    # Add the header in
    my $h = { pdbid => $pdb, header => $header, chain => {%fields} };
    return $h;
}

sub _header {
    my ($pdbcfh, $pdb) = @_;

    my $first = <$pdbcfh>;
    my @fields = split ' ', $first;

    # Remove leading comment
    shift @fields if $fields[0] eq '%';

    # Remove date and entry 24-OCT-00   1G3N
    pop @fields if $fields[-1] eq uc($pdb);
    pop @fields if $fields[-1] =~ /\d{2}-[A-Z]{3}-\d{2}/;

    # Concate the rest back together
    my $desc = join(' ', @fields);
    return $desc;
}

sub _chains {
    my ($pdbcfh,) = @_;
    my %chain2desc;
    while (my $line = <$pdbcfh>) {
        my ($mol) = $line =~ /MOLECULE:\s*(.*)/;
        next unless $mol;
        $mol =~ s/;? +$//g;
        $line = <$pdbcfh>;
        my ($chains) = $line =~ /CHAIN:\s*(.*)/;
        $chains =~ s/[^A-Z0-9a-z]//g;
        my @chains = split '', $chains;
        $chain2desc{$_} = $mol for @chains;
    }
    return %chain2desc;
}

1;
