#!/usr/bin/env perl

=head1 NAME

SBG::InteractionIO - Reads interactions and their templates from CSV file

=head1 SYNOPSIS

 use SBG::InteractionIO;
 my $interaction = new SBG::NetworkIO(file=>"interactions.csv")->read;

=head1 DESCRIPTION

Input routines for building up L<SBG::Interaction> objects from CSV file
input. 

The input format contains one interaction per line, with this format:
(Fields are white-space separated)

 component1 component2 pdbid1 { descriptor } pdbid1 { descriptor }

Where:

component1/component2 are labels for the interacting proteins. These can be any
label, but accession numbers, e.g. UniProt would be sensible.

template1/template2 are any labels for the structures upon which
component1/component2 are modelled. These can be any labels, but L<SBG::STAMP>
prefers it when the first four characters of the label are the PDB ID (case
insensitive) of the model structure.

The descriptors are regular STAMP descriptors, in { braces }.  See:
http://www.compbio.dundee.ac.uk/manuals/stamp.4.2/node29.html

Example:

 RRP42 RRP43  2br2b { CHAIN B } 2br2d { CHAIN D } 

=head1 SEE ALSO

L<SBG::Interaction> , L<SBG::IO>

=cut

################################################################################

package SBG::InteractionIO;
use Moose;
extends qw/Moose::Object Exporter/;
our @EXPORT_OK = qw/parse/;

use Text::ParseWords;

use SBG::Interaction;
use SBG::Seq;
use SBG::Domain;
use SBG::Template;
use SBG::HashFields;

################################################################################
# Accessors



################################################################################
=head2 read

 Function: Reads the next interaction from the file
 Example : my $xaction = $io->read();
 Returns : L<SBG::Interaction>, until end-of-file
 Args    : NA

E.g.:

RRP41 RRP42  2br2 { CHAIN A } 2br2 { CHAIN B }
# or
RRP41 RRP42  2br2 { A 5 _ to A 220 _ } 2br2 { B 1 _ to B 55 _ }

=cut
sub read {
    my ($self) = @_;
    my $fh = $self->fh;

    while (<$fh>) {
        # Skip #-comments and %-comments and blank lines
        next if (/^\s*\#/ || /^\s*\%/ || /^\s*$/);
        chomp;

        my $interaction = parse($_);
        return $interaction if $interaction;
    }
    # End of file
    return;
} # read



# Returns SBG::Interaction, give a line to parse
sub parse {
    my ($line) = @_;
    my ($comp1, $comp2, $pdbid1, $descr1, $pdbid2, $descr2) = _parse($line);
    my $templ1 = _make_templ($comp1, $pdbid1, $descr1);
    my $templ2 = _make_templ($comp2, $pdbid2, $descr2);
    my $iactionid = "$templ1--$templ2";
    my $iaction = new SBG::Interaction(-id=>$iactionid);
    $iaction->template($comp1,$templ1);
    $iaction->template($comp2,$templ2);
    return $iaction;
}


# return ($comp1, $comp2, $pdbid1, $descr1, $pdbid2, $descr2);
sub _parse {
    my ($line) = @_;

   # Get the stuff in { brackets } first: the STAMP domain descriptors
   my ($head, $descr1, $pdbid2, $descr2) = 
       parse_line('\s*[{}]\s*', 0, $line);
   # Then parse out everything else from the beginning, just on whitespace
   my @fields = parse_line('\s+', 0, $head);
   # Take the last three "words", ignoring any preceeding comments or junk
   my ($comp1, $comp2, $pdbid1) = @fields[-3,-2,-1];

   unless ($comp1 && $comp2 && $pdbid1 && $pdbid2) {
       warn("Cannot parse interaction line:\n", $line);
       return;
   }
   return ($comp1, $comp2, $pdbid1, $descr1, $pdbid2, $descr2);

} # _parse_line


# Create SBG::Template, given accession_number for sequence and domain details
sub _make_templ {
    my ($comp, $pdbid, $descr) = @_;
    my $seq = new SBG::Seq(-accession_number=>$comp);
    my $dom = new SBG::Domain(pdbid=>$pdbid,descriptor=>$descr);
    my $templ = new SBG::Template(seq=>$seq,domain=>$dom);
    return $templ;
}


################################################################################
__PACKAGE__->meta->make_immutable;
1;
