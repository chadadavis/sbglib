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
use base qw/Exporter/;
our @EXPORT_OK = qw/pdb_chain2uniprot_acc uniprot2gene tdracc2desc/;

use strict;
use warnings;
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
    our $base_url = "http://www.rcsb.org/pdb/rest/das/pdb_uniprot_mapping/alignment?query=";
    my $url = $base_url . $pdb . '.' . $chain;
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
    my ($id) = $content =~ 
        m|<alignObject.*?dbAccessionId="(.*?)".*?dbSource="UniProt".*?/>|;
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
    
    my $dbh = SBG::U::DB::connect('3dr_complexes');
    our $sth_gene;
    $sth_gene ||= $dbh->prepare(
        join ' ',
        'SELECT',
        'gene_name',
        'FROM',
        'yeast_proteins',
        'where',
        'uniprot_acc=?',
        );
    my $res = $sth_gene->execute($uniprot);
    my $a = $sth_gene->fetchrow_arrayref;
    return unless $a && @$a;
    return $a->[0];
}

sub tdracc2desc {
	my ($target) = @_;
    # TODO REFACTOR into an external 3DR module
    my $dbh = SBG::U::DB::connect('3DR');
    my $arr = $dbh->selectall_arrayref(join ' ',
        "SELECT description FROM thing",
        "where acc=${target} and type_acc='Complex' and source_acc='3DR'");
    my ($desc) = flatten $arr;
    return $desc;
}
	

1;
__END__


