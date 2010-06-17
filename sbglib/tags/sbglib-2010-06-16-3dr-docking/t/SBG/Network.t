#!/usr/bin/env perl

use Test::More 'no_plan';

use Carp;
use Data::Dumper;
use Data::Dump qw/dump/;

use Moose::Autobox;

use FindBin qw/$Bin/;
use lib "$Bin/../../lib/";
use SBG::U::Test 'float_is';
use SBG::Network;
use SBG::Node;
use SBG::Seq;
use SBG::Interaction;

use SBG::U::Log qw/log/;
my $DEBUG;
$DEBUG = 1;
SBG::U::Log::init( undef, loglevel => 'DEBUG' ) if $DEBUG;


# Sequences becomes nodes become networks
my $seq1 = new SBG::Seq(-display_id=>'RRP43');
my $seq2 = new SBG::Seq(-display_id=>'RRP41');
my $net = new SBG::Network;

# Node objects are automatically created from sequence objects, and added
$net->add_seq($seq1,$seq2);

# Test node indexing
my $node1 = new SBG::Node($seq1);
my $node2 = new SBG::Node($seq2);
my $gotnode = $net->nodes_by_id('RRP43');
is($gotnode, $node1, "nodes_by_id");

# Add an interaction and re-fetch it
my $interaction = new SBG::Interaction;
$net->add_interaction(
    -nodes=>[ $node1, $node2 ],
    -interaction => $interaction,
    );
my %iactions = $net->get_interactions($net->nodes);
my ($got) = values %iactions;
is_deeply([sort $got->nodes], [sort $node1, $node2], "add_interaction");

# Test symmetry
use Bio::SeqIO;
use Benchmark qw(:all) ;

sub _symm_test { 
	my ($file, $method, $expected) = @_;
	
    my $cc = _get_symm ($file, $method);
    my $str = _nested2str(@$cc);

    # Split and rejoin, sorted    
    my @expected = map { s/[()]//g; [ split ',' ] } split('\),\(', $expected);
    $expected = _nested2str(@expected);
    is($str, $expected, "${method}()");
    
}

sub _get_symm {
    my $file   = shift;
    my $method = shift || 'symmetry';

    my $io = Bio::SeqIO->new( -file => $file );
    my $snet = SBG::Network->new;
    while ( my $seq = $io->next_seq ) { $snet->add_seq($seq); }
    my $cc;
    my $time = timeit(1, sub { $cc = $snet->$method });
    diag "$method: ", timestr($time);
    return $cc;
}

sub _nested2str {
    join(',', sort map { '(' . join(',',sort @$_) . ')' } @_);
}


_symm_test("$Bin/data/bovine-f1-atpase.fa", 'symmetry',
    '(1e79A,1e79B,1e79C),(1e79D,1e79E,1e79F),(1e79G),(1e79H),(1e79I)');
                
_symm_test("$Bin/data/bovine-f1-atpase.fa", 'symmetry2',
    '(1e79A,1e79B,1e79C),(1e79D,1e79E,1e79F),(1e79G),(1e79H),(1e79I)');

_symm_test("$Bin/data/bovine-f1-atpase.fa", 'symmetry3',
    '(1e79A,1e79B,1e79C),(1e79D,1e79E,1e79F),(1e79G),(1e79H),(1e79I)');


# A (much) larger test (for speed)
my $cc3 = _get_symm("$Bin/data/522.fa", 'symmetry3');
my $str3 = _nested2str(@$cc3);
diag "str3 ", $str3;

my $cc2 = _get_symm("$Bin/data/522.fa", 'symmetry2');
my $str2 = _nested2str(@$cc2);
diag "str2 ", $str2;

my $cc1 = _get_symm("$Bin/data/522.fa");
my $str1 = _nested2str(@$cc1);
diag "str1 ", $str1;






    

