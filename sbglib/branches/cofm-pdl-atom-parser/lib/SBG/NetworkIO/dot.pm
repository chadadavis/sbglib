#!/usr/bin/env perl

=head1 NAME

SBG::NetworkIO::graphviz - 

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::Network> , L<SBG::IOI>

=cut



package SBG::NetworkIO::dot;
use Moose;

with qw/
SBG::IOI
/;


use Graph::Writer::GraphViz;
use File::Basename;

use SBG::Network;

use SBG::U::List qw/maprange mapcolors/;


# Caches to prevent duplicate printing
has 'nodes' => (
    is => 'rw',
    isa => 'HashRef',
    default => sub { {} },
    );
    
has 'interactions' => (
    is => 'rw',
    isa => 'HashRef',
    default => sub { {} },
    );
    
    
my %color_map = (
    'struct'    => '#00ff00', # green
    'docking'   => '#cccccc', # grey
    'templates' => '#00ffff', # cyan
    'dom_dom'   => '#00ffff', # cyan
    'transdb'   => '#00ffff', # cyan
    
    );
    
my $newline = '&#13;&#10;';

=head2 read

 Function: Reads the interaction lines from the stream and produces a network
 Example : my $net = $io->read();
 Returns : L<SBG::Network>
 Args    : NA

NB Not implemented
=cut
sub read {
    my ($self,) = @_;
    my $fh = $self->fh;

    warn "Not implemented";
    my $net = new SBG::Network;

    while (my $line = <$fh>) {
        next unless $line =~ //;
        chomp;
    }
    return $net;

} # read



=head2 write

 Function: 
 Example : 
 Returns : 
 Args    : 

This write manually generates a graphviz format that is able to accomodate
multiple edges.

# TODO options? Can GraphViz module still be used to parse these out?

=cut
sub write {
    my ($self, $graph, $name) = @_;
       
    $name ||= $graph->modelid() || $graph->targetid() || 'network';
    $self->write_begin($name);
    
    $self->write_body($graph, $name);

    $self->write_end();

    return $self;
}


# TODO Really needs to be worked in somewhere else: SBG::Seq or SBG::Node maybe
use SBG::U::DB;
sub uniprot2gene {
    my ($uniprot) = @_;
        
    my $dbh = SBG::U::DB::connect('3dr_complexes');
    our $sth_gene;
    $sth_gene ||= $dbh->prepare(
        join ' ',
        'SELECT',
        join(',',qw/uniprot_acc gene_name description uniprot_id/),
        'FROM',
        'yeast_proteins',
        'where',
        'uniprot_acc=?',
        );
    our %cache;
    my $cached = $cache{$uniprot};
    return $cached if $cached;
    my $res = $sth_gene->execute($uniprot);
    my $a = $sth_gene->fetchrow_hashref;
    return unless $a && %$a;
    $cache{$uniprot} = $a;
    return $a;
}


sub write_begin {
	my ($self, $name) = @_;
	$name ||= 'network';
	
    my $str = join("\n",
                   "graph \"$name\" {",
                   "\tgraph [ size=8, tooltip=\"\" ]",
                   "\tnode [fontsize=8, penwidth=1 ]",
                   "\tedge [fontsize=6 ]",
                   ,"");

    my $fh = $self->fh;
    print $fh $str;
    return ($str);
}


sub write_end {
    my ($self, ) = @_;

    my $fh = $self->fh;
    my $str = "\n}\n";
    print $fh $str;
    return $str;
}

sub _write_node {
	my ($self, $u) = @_;
    # Keep track of what's been done to avoid duplicates
    my $nodes = $self->nodes;
    
    return '' if $nodes->{$u};
	
	# Uniprot, using uniprot acc
#	our $nodeurl = "http://www.uniprot.org/uniprot";
    # Pfam, via uniprot acc
	our $nodeurl = "http://pfam.sanger.ac.uk/protein";
	
	my ($acc, $id, $gene, $desc) = ('') x 4; 
	
	my $up = uniprot2gene($u);
    if ($up) {
        ($acc, $id, $gene, $desc) = 
            ($up->{'uniprot_acc'}, $up->{'uniprot_id'}, 
            $up->{'gene_name'}, $up->{'description'});
    }           
    my $ulabel = $gene || $u;
   
    my $str .= 
        "\t\"$ulabel\" [ " . 
        join(', ',
        "URL=\"$nodeurl/$acc\"",
        "tooltip=\"" . join($newline, $gene, $acc, $id, $desc) . "\"",
        ) .
        " ]\n";
	
	$nodes->{$u} = 1;
	return $str;
}	


sub write_body {
	my ($self, $graph, $name) = @_;
	$name ||= $graph->targetid() || 'network';
	
	my $str = '';
	our $tdrurl = "http://3drepertoire.russelllab.org/cgi-bin/final_paper.pl";
	
	# Keep track of what's been done to avoid duplicates
	my $interactions = $self->interactions;
	
    # For each connection between two nodes, get all of the templates
    foreach my $e ($graph->edges) {
        # Swap these, because head and tail are semantically reversed below
        my ($v, $u) = @$e;
        $str .= $self->_write_node($u);
        $str .= $self->_write_node($v);
                        
        # Names of attributes for this edge
        foreach my $attr ($graph->get_edge_attribute_names($u, $v)) {
            # The actual interaction object for this template
            my $iaction = $graph->get_interaction_by_id($attr);
            # Skip duplicates
            my $iactionkey = "$name--$iaction";
            next if $interactions->{$iactionkey};

            my $source = $iaction->source || '';
            my $penwidth = maprange($iaction->weight,1,1000,1,50);
            my $url = "${tdrurl}?id1=${u}&id2=${v}";
                
            my $scores = $iaction->scores;
            my $color;
            if ($source eq 'docking') {
                # Gradient from black to middle grey
                $color = mapcolors(
                    $scores->{'docking'}, 570, 4076, '#000000', '#cccccc');
            } else {
                # Gradient from red to green
                $color = mapcolors(
                    $scores->{'avg_seqid'}, 0, 100, '#ff0000', '#00ff00');
            }
                            
            my $scorelabel;
            foreach my $key (keys %$scores) { 
                $scorelabel .= sprintf("%s\t%f$newline", $key, $scores->{$key});
            }
            $scorelabel .= sprintf("%s\t%f$newline", 'weight', $iaction->weight);

            my ($ulabel, $vlabel) = ('') x 2;
            my $up_u = uniprot2gene($u);
            my $up_v = uniprot2gene($v);
            $ulabel = $up_u->{'gene_name'} if $up_u;
            $vlabel = $up_v->{'gene_name'} if $up_v;
            my $usubject = $iaction->get($u)->subject;
            my $vsubject = $iaction->get($v)->subject;
            
            my $tooltip = join($newline,
                $source,
                sprintf("%s\tvia\t%s", $ulabel, $usubject),
                 sprintf("%s\tvia\t%s", $vlabel, $vsubject),
                $scorelabel,
                );
                            
            $str .= "\t\"$ulabel\" -- \"$vlabel\" [" . 
                join(', ',
                    "color=\"$color\"", 
                    "penwidth=$penwidth", 
                    "tooltip=\"$tooltip\"",
                    "URL=\"$url\"",
                    "];\n");
            $interactions->{$iactionkey} = 1;
                    
        }
    }

    my $fh = $self->fh;
    print $fh $str;
    return $str;

} # write_body


__PACKAGE__->meta->make_immutable;
no Moose;
1;
