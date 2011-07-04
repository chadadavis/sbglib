#!/usr/bin/env perl

use Test::More 'no_plan';

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib/";

use SBG::U::DB;
my $dbh = SBG::U::DB::connect();
unless($dbh) {
    ok warn "skip : no database\n";
    exit;
}

use Moose::Autobox;
use List::Util qw/min/;

use SBG::DB::res_mapping qw/query aln2locations/;
use SBG::U::DB qw/chain_case/;

use Bio::AlignIO;
use SBG::Domain::Atoms;

my $file = shift || "$Bin/../data/aln.aln";
my $in = Bio::AlignIO->new(-file=>$file);
my $aln = $in->next_aln;


# Map pdbseq sequence coordinates to PDB residue IDs
my %seqcoords = aln2locations($aln);
my %resids;
my ($key, $pdbid, $chainid);
my $resids;

$key = '2z3gA';
my $seqcoords1 = $seqcoords{$key};
is ($seqcoords1->length, 96, 'aln2locations length');
is ($seqcoords1->[0], 26, 'aln2locations start');
is ($seqcoords1->[-1], 122, 'aln2locations end');

($pdbid,$chainid) = $key =~ /(....)(.)/;
$resids = query($pdbid, $chainid, $seqcoords1);
is ($resids->length, $seqcoords1->length, 'mapping same length');
is ($resids->[0], 27, 'res_mapping start');
is ($resids->[-1], 123, 'res_mapping end');

$key = 'pdb|1UX1|A';
my $seqcoords2 = $seqcoords{$key};
is ($seqcoords1->length, $seqcoords2->length, 'aligned seqs same length');

is ($seqcoords2->length, 96, 'aln2locations length');
is ($seqcoords2->[0], 24, 'aln2locations start');
is ($seqcoords2->[-1], 122, 'aln2locations end');

($pdbid, $chainid) = $key =~ /^pdb\|(....)\|(\S*)$/;
$resids = query($pdbid, $chainid, $seqcoords2);
cmp_ok ($resids->length, '==', $seqcoords2->length, 'mapping same length');
is ($resids->[0], 24, 'res_mapping start');
is ($resids->[-1], 122, 'res_mapping end');



$TODO = 'Test boundary cases';
ok(0);

$TODO = 'Test negatives residue IDs';
ok(0);

$TODO = 'Test ranges, verify ordering';
ok(0);



__END__


