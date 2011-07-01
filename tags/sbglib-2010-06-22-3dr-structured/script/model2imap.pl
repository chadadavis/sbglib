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
    
    $io->write_body($net);  
       
}
$io->write_end();
}

# Run graphviz, producing PNG and MAP files
`circo -Tcmapx -o${target}.map -Tpng -o${target}.png ${target}.dot`;

# Coule use TT here for the HTML
open my $html_fh, ">${target}.html";
print $html_fh <<EOF;
<a name="$target" />
<p>
3DRepertoire complex <a href="http://3drepertoire.russelllab.org/Thing?db=3DR&type_acc=Complex&acc=${target}&source_acc=3DR">$target</a>
</p>
<p>
$desc
</p>
<img src="${target}.png" usemap="#${target}" />
<br />
EOF
close $html_fh;
`cat ${target}.map >> ${target}.html`;
`cat ${target}.html >> all.html`;
exit;

