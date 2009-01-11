#!/usr/bin/env perl

=head1 NAME

SBG::CofM - Computes STAMP centre-of-mass of an SBG::Domain

=head1 SYNOPSIS

 use SBG::CofM;

=head1 DESCRIPTION

Looks up cached results in database, if available. This is only the case for
full chains. Otherwise, cofm is executed anew.

Also fetches radius of gyration of the centre of mass.

=head1 SEE ALSO

L<SBG::Domain>

=cut

################################################################################

package SBG::CofM;
use SBG::Root -base;

our @EXPORT_OK = qw(cofm);

use warnings;
use File::Temp qw(tempfile);
use Text::ParseWords;

use SBG::DB;
use SBG::Domain;
use SBG::DomainIO;
use SBG::Complex;


################################################################################
=head2 cofm

 Title   : cofm
 Usage   : cofm($dom)
 Function: Sets the center of mass of an L<SBG::Domain>
 Example : cofm($dom)
 Returns : The $dom, now containing $dom->cofm;
 Args    : L<SBG::Domain>

Gets centre-of-mass of an SBG::Domain.

If the Domain is an entire chain, the database cache is queried first. Otherwise
cofm is run locally, if available. 

B<cofm> must be in your PATH, or defined in the B<embl.ini> file

The DB cache stores uppercase PDB IDs. The B<cofm> program will accept any case.

=cut
sub cofm {
    my ($thing, $descriptor, $label) = @_;
    my $pdbid;
    if (ref($thing) eq 'SBG::Complex') {
        return cofm_complex($thing);
    } elsif (ref($thing) eq 'SBG::Domain') {
        # Get fields from existing object
        $pdbid = $thing->pdbid;
        $descriptor ||= $thing->descriptor;
        $label ||= $thing->label;
    } else {
        # Assume it is just the PDB ID
        $pdbid = $thing
    }

    my @fields;

    # If descriptor contains just one full chain, try the cache first;
    if ($descriptor =~ /^\s*CHAIN\s+([a-zA-Z_])\s*$/i) {
        @fields = cofm_query($pdbid, $1);
    } else {
        # Couldn't get from DB, try running computation locally
        @fields = cofm_run($pdbid, $descriptor);
    }

    unless (@fields) {
        $logger->error("Cannot get centre-of-mass for ${pdbid} ${descriptor}");
        return;
    }

    my ($x, $y, $z, $rg, $file, $found_descriptor) = @fields;
    my $dom = new SBG::Domain(-pdbid=>$pdbid,
                              -descriptor=>$descriptor,
                              -rg=>$rg,
                              -file=>$file,
        );
    $dom->cofm($x, $y, $z);
    $dom->label($label) if $label;
    return $dom;

} # cofm


sub cofm_complex {
    my ($complex) = shift;
    foreach my $name ($complex->names) {
        $complex->comp($name) = cofm($complex->comp($name))
    }
    return $complex;
}


################################################################################
=head2 cofm_query

 Title   : cofm_query
 Usage   : my (@xyz, $rg, $file, $descriptor) = SBG::CofM::cofm_query('2nn6', 'A');
 Function: Fetches centre-of-mass and radius of gyration of known PDB chains
 Example : my (@xyz, $rg, $file, $descriptor) = SBG::CofM::cofm_query('2nn6', 'A');
 Returns : XYZ coordinates, radius of gyration, path to file, STAMP descriptor
 Args    : pdbid - string (not case sensitive)
           chainid - character (case sensitive)

Looks for cached results in database (defined in B<embl.ini>).

Only appropriate for full-chain queries. Otherwise, see L<cofm_run>

The DB cache stores uppercase PDB IDs.

=cut
sub cofm_query {
    my ($pdbid, $chainid) = @_;
    $logger->trace("$pdbid,$chainid");
    my $db = $config->val('cofm', 'db') || "trans_1_5";
    my $dbh = dbconnect(-db=>$db) or return undef;
    # Static handle, prepare it only once
    our $cofm_sth;
    $cofm_sth ||= $dbh->prepare("select cofm.Cx,cofm.Cy,cofm.Cz," .
                                "cofm.Rg,entity.file,entity.description " .
                                "from cofm, entity " .
                                "where " .
                                "bad = 0 and " .
                                "cofm.id_entity=entity.id and " .
                                "(entity.acc=? or entity.acc=?)"
        );
    unless ($cofm_sth) {
        $logger->error($dbh->errstr);
        return undef;
    }

    $pdbid = uc $pdbid;
    # Check PDB and PQS structures
    my $pdbstr = "pdb|$pdbid|$chainid";
#     my $pqsstr = "pqs|$pdbid|$chainid";
    # NB don't naively check PQS as the chain ID might be different
    my $pqsstr = "pdb|$pdbid|$chainid";
    if (! $cofm_sth->execute($pdbstr, $pqsstr)) {
        $logger->error($cofm_sth->errstr);
        return undef;
    }

    # ($x, $y, $z, $rg, $file, $descriptor);
    return $cofm_sth->fetchrow_array();
} # cofm_query


################################################################################
=head2 cofm_run

 Title   : cofm_run
 Usage   : my (@xyz, $rg, $file, $descriptor) = SBG::CofM::cofm_run($dom);
 Function: Computes centre-of-mass and radius of gyration of STAMP domain
 Example : my (@xyz, $rg, $file, $descriptor) = SBG::CofM::cofm_run($dom);
 Returns : XYZ coordinates, radius of gyration, path to file, STAMP descriptor
 Args    : L<SBG::Domain>

Runs external B<cofm> appliation. Must be in your environment's B<$PATH>

'descriptor' and 'pdbid' (or 'label') must be defined in the L<SBG::Domain>

=cut
sub cofm_run {
    my ($pdbid, $descriptor) = @_;
    return unless $pdbid && $descriptor;

    my $dom = new SBG::Domain(-pdbid=>$pdbid,-descriptor=>$descriptor);
    my ($tfh, $path) = tempfile();
    my $io = new SBG::DomainIO(-fh=>$tfh);
    $io->write($dom, -id=>'stampid');
    $io->flush;
    unless (-s $path) {
        $logger->error("Failed to write Domain to: $path");
        return;
    }

    # NB the -v option is necessary if you want the filename of the PDB file
    my $cofm = $config->val('cofm','executable') || 'cofm';
    my $cmd = "$cofm -f $path -v |";
    my $cofmfh;
    unless (open $cofmfh, $cmd) {
        $logger->error("Failed:\n\t$cmd\n\t$!");
        return undef;
    }

    my ($x, $y, $z);
    my $rg;
    my $file;
    my $found_descriptor;
    while (<$cofmfh>) {
        if (/^Domain\s+\S+\s+(\S+)/i) {
            $file = $1;
        } elsif (/^\s+chain\s+(\S+)/i) {
            $found_descriptor = "CHAIN $1";
        } elsif (/^\s+from\s+([a-zA-Z_])\s+(\d+)\s+to\s+([a-zA-Z_])\s+(\d+)/i) {
            $found_descriptor = "$1 $2 _ to $3 $4 _";
        } elsif (/^REMARK Domain/) {
            my @a = quotewords('\s+', 0, $_);
            ($rg, $x, $y, $z) = ($a[10], $a[16], $a[17], $a[18]);
        }
    }

    # Check that $descriptor eq $found_descriptor 
    $logger->error("Descriptors unequal: $descriptor, $found_descriptor") unless
        $descriptor eq $found_descriptor;

    return ($x, $y, $z, $rg, $file, $found_descriptor);

} # cofm_run




################################################################################
1;



################################################################################
1;
