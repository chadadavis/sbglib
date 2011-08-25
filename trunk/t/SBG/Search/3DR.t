#!/usr/bin/env perl

use strict;
use warnings;
use Test::More 'no_plan';
use Carp;
$SIG{__DIE__} = \&confess;

use File::Temp qw/tempfile/;

use Moose::Autobox;
use Bio::SeqIO;

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib/";

use SBG::Seq;
use SBG::Network;
use SBG::Search::3DR;

use SBG::Debug;
use FindBin qw/$Bin/;
my $file = shift || "$Bin/030.fa";

my $seqio = Bio::SeqIO->new(-file => $file);
my $net = SBG::Network->new;
while (my $seq = $seqio->next_seq) {
    $net->add_seq($seq);
}
is(scalar($net->nodes), 4, "nodes");

my $tdr = SBG::Search::3DR->new;
unless ($tdr->_dbh) {
    ok warn "skip : no database\n";
    exit;
}

$net->build($tdr);
foreach my $int ($net->interactions()) {

    #	next if $int->source eq 'dom_dom';
    #    note join ' ', $int, $int->source, $int->weight;
}

