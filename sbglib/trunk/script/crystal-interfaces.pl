#!/usr/bin/env perl

# Tanmay's crystal interfaces extracted from symmetry operators

use Modern::Perl;
use Moose::Autobox;
use PDL;

use SBG::Domain;
use SBG::U::Test qw/pdl_equiv/;
use SBG::DomainIO::pdb;
use SBG::Run::rasmol;

use Bio::Tools::Run::QCons;


foreach my $pdbid (@ARGV) {

my $dom = SBG::Domain->new(pdbid=>$pdbid, descriptor=>"CHAIN A");
my $symops = $dom->symops;

my $no_rotation = pdl [ 1, 0, 0 ], [ 0, 1, 0 ], [ 0, 0, 1];
my $no_translation = pdl(0,0,0)->transpose;

my $noutputs;

foreach my $symop (@$symops) {

    # Skip if there is a rotation
    my $rot = $symop->rotation;
    unless (pdl_equiv($rot, $no_rotation)) {
#        say "Skipping rotation: $rot";
        next;
    }

    # Skip if there is no translation
    my $transl = $symop->translation;
    if (pdl_equiv($transl, $no_translation)) {
#    	say "Skipping translation: $transl";
    	next;
    }
    
    
    $noutputs++;
    my $crystal_neighbor = $dom->clone;
    $symop->apply($crystal_neighbor);

    my $outfile = sprintf("%s-%02d.pdb", $pdbid, $noutputs);
    my $pdbio = SBG::DomainIO::pdb->new(file=>">$outfile");
    $pdbio->write($dom, $crystal_neighbor);
    say "$outfile via: $symop";
    
    # Check contact
    my $qcons = Bio::Tools::Run::QCons->new(file=>$outfile, chains => ['A', 'B']);
    my $contacts = $qcons->residue_contacts;
    unless ($contacts->length) {
    	unlink $outfile;
    	next;
    }

    
    # Check uniqueness via iRMSD
    
#    rasmol($dom, $crystal_neighbor);
    
    
} # foreach my $symop

} # foreach my $pdbid
