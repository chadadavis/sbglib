#!/usr/bin/env perl

# Tanmay's crystal interfaces extracted from symmetry operators

use Modern::Perl;
use Moose::Autobox;
use PDL;
use Data::Dump qw/dump/;

# Local libraries
use FindBin qw/$Bin/;
use lib "$Bin/../lib/";

use SBG::Domain;
use SBG::U::Test qw/pdl_equiv/;
use SBG::DomainIO::pdb;
use SBG::Run::rasmol;

use Bio::Tools::Run::QCons;
use SBG::Run::naccess qw/sas_atoms buried/;


foreach my $pdbid (@ARGV) {

my $dom = SBG::Domain->new(pdbid=>$pdbid);
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
    
    # How many different dimers have we produced so far
    $noutputs++;
    # Create the crystal-induced neighbor domain
    my $crystal_neighbor = $dom->clone;
    $symop->apply($crystal_neighbor);
    # Write the dimer to a PDB file
    my $base = sprintf("%s-%02d", $pdbid, $noutputs);
    my $outfile = $base . '.pdb';
    my $pdbio = SBG::DomainIO::pdb->new(file=>">$outfile");
    $pdbio->write($dom, $crystal_neighbor);
    
    # Check contact, with Qcontacts
    my $qcons = Bio::Tools::Run::QCons->new(file=>$outfile, chains => ['A', 'B']);
    # Summarize by residue (rather than by atom)
    my $res_contacts = $qcons->residue_contacts;
    unless ($res_contacts->length) {
        print STDERR "$outfile not in contact\n";
        # Don't save this PDB file if the dimer is not actually an interface
        unlink $outfile;
    	next;
    } else {
        print STDERR "$outfile via: $symop\n";
    }
#    my $atom_contacts = $qcons->atom_contacts;
    
    # Buried surface
    my $buried = buried($dom, $crystal_neighbor);
    
    say sprintf "%s\t%d\t%.2f", $outfile, $res_contacts->length, $buried;
    open my $fh, ">${base}.csv";
    foreach my $contact ($res_contacts->flatten) {
    	my $a = $contact->{'res1'}{'name'} . $contact->{'res1'}{'number'};
    	my $b = $contact->{'res2'}{'name'} . $contact->{'res2'}{'number'};
    	print $fh join("\t", $outfile, $a, $b), "\n";
    }
    
#    rasmol($dom, $crystal_neighbor);
    
    
} # foreach my $symop

} # foreach my $pdbid
