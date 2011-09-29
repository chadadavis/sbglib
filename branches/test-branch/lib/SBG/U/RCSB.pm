#!/usr/bin/env perl

=head1 NAME

SBG::U::RCSB - Routines for mapping database identifiers

=head1 SYNOPSIS

 use SBG::U::Map qw/pdb_chain2uniprot_acc;
 my $uniprot_acc = pdb_chain2uniprot_acc('3jqoa');
 my $uniprot_acc = pdb_chain2uniprot_acc('3jqo|a');
 my $uniprot_acc = pdb_chain2uniprot_acc('3jqo.a');
 my $uniprot_acc = pdb_chain2uniprot_acc('3jqo.A');
 
 die unless $uniprot_acc eq 'Q46702';

=head1 DESCRIPTION

Chain identifiers are case sensitive. PDB identifiers are not.

=head1 SEE ALSO

L<Bio::DB::BioFetch>

=cut

package SBG::U::Map;
use strict;
use warnings;

use base qw/Exporter/;
our @EXPORT_OK = qw/pdb_chain2uniprot_acc/;

use Carp;
use Log::Any qw/$log/;

use LWP::Simple;
use IO::String;
use XML::XPath;

sub pdb_chain2uniprot_acc {
    my ($id) = @_;
    my $re = '([[:digit:]][[:alnum:]]{3})[[:punct:]]?([[:alnum:]]{1,2})';
    my ($pdb, $chain) = $id =~ /$re/;
    our $base_url =
        "http://www.rcsb.org/pdb/rest/das/pdb_uniprot_mapping/alignment?query=";
    my $url     = $base_url . $pdb . '.' . $chain;
    my $content = get($url);
    if ($content =~ /Bad command arguments/i) {
        warn "Failed to get UniProt Acc for $id\n";
        return;
    }
    my $io         = IO::String->new($content);
    my $xp         = XML::XPath->new(ioref => $io);
    my $query      = '//alignObject[@dbSource="UniProt"]';
    my ($node)     = $xp->findnodes($query);
    my $uniprotacc = $node->getAttribute('dbAccessionId');
    return $uniprotacc;
}

1;
__END__


