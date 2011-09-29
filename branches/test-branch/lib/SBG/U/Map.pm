#!/usr/bin/env perl

=head1 NAME

SBG::U::Map - Routines for mapping database identifiers

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
our @EXPORT_OK = qw/pdb_chain2uniprot_acc uniprot2gene tdracc2desc chain_case/;

use Carp;
use Log::Any qw/$log/;

use LWP::Simple;
use IO::String;

use SBG::U::DB;
use SBG::U::List qw/flatten/;

#use XML::XPath;

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

    # regex approach is less stable (assumes order of attributes), but faster
    my $uniprotacc = _xml_regex($content);

    # And the XPath produces a warning in IO::String, but is also correct
    #    my $uniprotacc = _xml_xpath($content);
    return $uniprotacc;
}

sub _xml_regex {
    my $content = shift;
    my ($id) = $content
        =~ m|<alignObject.*?dbAccessionId="(.*?)".*?dbSource="UniProt".*?/>|;
    return $id;
}

#sub _xml_xpath {
#    my $content = shift;
#    my $io = IO::String->new($content);
#    my $xp = XML::XPath->new(ioref=>$io);
#    my $query = '//alignObject[@dbSource="UniProt"]';
#    my ($node) = $xp->findnodes($query);
#    my $uniprotacc = $node->getAttribute('dbAccessionId');
#    return $uniprotacc;
#}

# Only for S. cerevisiae sequences
sub uniprot2gene {
    my ($uniprot) = @_;
    my $dsn = SBG::U::DB::dsn(database=>'3dr_complexes');
    my $dbh = SBG::U::DB::connect($dsn);
    my $sth_gene = $dbh->prepare_cached(
        join ' ', 
        'SELECT', 'gene_name', 
        'FROM', 'yeast_proteins', 
        'where', 'uniprot_acc=?',
    );
    my $res = $sth_gene->execute($uniprot);
    my $a   = $sth_gene->fetchrow_arrayref;
    return unless $a && @$a;
    return $a->[0];
}

sub tdracc2desc {
    my ($target) = @_;

    # TODO REFACTOR into an external 3DR module
    my $dsn = SBG::U::DB::dsn(database=>'3DR');
    my $dbh = SBG::U::DB::connect($dsn);
    my $arr = $dbh->selectall_arrayref(
        join ' ',
        "SELECT description FROM thing",
        "where acc=${target} and type_acc='Complex' and source_acc='3DR'"
    );
    my ($desc) = flatten $arr;
    return $desc;
}

=head2 chain_case

 Function: Converts between e.g. 'a' and 'AA'
 Example : $chain = chain_case('a'); $chain = chain_case('AA');
 Returns : lowercase converted to double uppercase, or vice versa
 Args    : 

The NCBI Blast standard uses a double uppercase to represent a lower case chain identifier from the PDB. I.e. when a structure has more than 36 chains, the first 26 are named [A-Z] the next 10 are named [0-9], and the next next 26 are named [a-z]. The NCBI Blast is not case-sensitive, so it converts the latter to double uppercase, i.e. 'a' becomes 'AA'.

Given 'a', returns 'AA';

Given 'AA', returns 'a';

Else, returns the identity;

TODO REFACTOR belongs in SBG::U::Map
=cut

sub chain_case {
    my ($chainid) = @_;

    # Convert lowercase chain id 'a' to uppercase double 'AA'
    if (!$chainid) {
        $chainid = '';
    }
    elsif ($chainid =~ /^([a-z])$/) {
        $chainid = uc $1 . $1;
    }
    elsif ($chainid =~ /^([A-Z])\1$/) {
        $chainid = lc $1;
    }

    return $chainid;

}    # chain_case

1;
__END__


