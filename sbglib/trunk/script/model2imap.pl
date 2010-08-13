#!/usr/bin/env perl

=head1 NAME

Docs 

 http://www.graphviz.org/cvs/doc/info/output.html#d:cmapx

=cut



use strict;
use warnings;

use File::Basename;
use File::Spec::Functions;
use Log::Any qw/$log/;
use Carp;

use Moose::Autobox;

# Local libraries
use FindBin qw/$Bin/;
use lib "$Bin/../lib/";
use SBG::Role::Storable qw/retrieve/;
use SBG::U::Object qw/load_object/;
use SBG::U::Run qw/frac_of getoptions start_lock end_lock/;
use SBG::U::Log;

use SBG::NetworkIO::dot;

my %ops = getoptions(
    );
exit unless @ARGV;

# DOT file output
my $first = $ARGV[0];
exit unless $first && -s $first;
my $model = load_object($first);
my $target = $model->target;
my $desc = $model->description;

unless ( -f "${target}.dot") {
print STDERR "Building DOT\n";

my $io = SBG::NetworkIO::dot->new(file=>">${target}.dot");
$io->write_begin($target);

foreach my $file (@ARGV) {
#    print STDERR "$file\n";
    # Load the object
    unless ($model = load_object($file)) {
        $log->error("$file is not an object");
        next;
    }
    
    my $net = $model->network;
    # Append to the target;    
    $io->write_body($net);
      
    # Our own per-model graphic:
    mkdir $target;
    my $id = $model->id;
    my $base = "${target}/${id}";
    $net->id($id);
    my $modeldotio = SBG::NetworkIO::dot->new(file=>">${base}.dot");
    $modeldotio->write($net);
    map2html($target, $desc, $id, $base);
    _model($model, $base);
    
    `cat ${base}.html >> ${target}/${target}.html`;
    
}
$io->write_end();
}


map2html($target,$desc);

`cat ${target}.html >> all.html`;

exit;


sub _model {
	my ($complex, $base) = @_;
	
	my $target = $complex->target;
	
    open my $fh, ">>${base}.html";
    foreach my $iaction ($complex->interactions->values->flatten) {
        print $fh "<p>\n";
        my $source = $iaction->source();
        print $fh "$iaction source=", $iaction->source, ' ' if $source;
        foreach my $score ($iaction->scores->keys->flatten) {
            print $fh "${score}=", $iaction->scores->at($score), " ";
        }
        print $fh "</p>\n";
    }
        
    print $fh "<p><a href=\"../../models/${base}.pdb\">PDB</a></p>\n";
    print $fh "<p><a href=\"../../models/${base}.dom\">STAMP DOM</a></p>\n";
    
    my @keys = $complex->keys->flatten;
    my $char = ord('A');
    foreach my $key (@keys) {
        my $model = $complex->get($key);
        my $seq = $model->query;
        my $dom = $model->subject;
        
        print $fh "<p>CHAIN ", chr($char), " ", $model->gene(), " ";
        foreach my $score ($model->scores->keys->flatten) {
            print $fh "${score}=", $model->scores->at($score), " ";
        }
        print $fh "</p>\n";
        
        print $fh "<p>", $dom->file, ' ', $dom->id, " { ", $dom->descriptor, " }</p>\n";
        
        
        # TODO BUG wrong if model has more than 26 chains
        $char++;
    }
    
    close $fh;
    
}


sub map2html {
    my ($target, $desc, $id, $base) = @_;
    $id ||= $target;
    $base ||= $id;
	# Run graphviz, producing PNG and MAP files
    `circo -Tcmapx -o${base}.map -Tpng -o${base}.png ${base}.dot`;

    # Note that the map contains the anchor that we want to link to. Put it first.
    `cat ${base}.map >> ${base}.html`;
    open my $html_fh, ">>${base}.html";
    print $html_fh <<EOF;
<p>
3DRepertoire complex <a href="http://3drepertoire.russelllab.org/Thing?db=3DR&type_acc=Complex&acc=${target}&source_acc=3DR">$target</a>
</p>
<p>
$desc
</p>
<img src="${id}.png" usemap="#${id}" />
<hr />
EOF
    close $html_fh;
}





