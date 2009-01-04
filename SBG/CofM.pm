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
use SBG::Root -base, -XXX;

our @EXPORT = qw(get_cofm);

use warnings;
use Carp;
use File::Temp qw(tempfile);
use Text::ParseWords;

use SBG::DB;
use SBG::Domain;
use SBG::DomainIO;



################################################################################
=head2 query

 Title   : query
 Usage   : my (@xyz, $rg, $file, $descriptor) = SBG::CofM::query('2nn6', 'A');
 Function: Fetches centre-of-mass and radius of gyration of known PDB chains
 Example : my (@xyz, $rg, $file, $descriptor) = SBG::CofM::query('2nn6', 'A');
 Returns : XYZ coordinates, radius of gyration, path to file, STAMP descriptor
 Args    : pdbid - string (not case sensitive)
           chainid - character (case sensitive)

Looks for cached results in database (defined in B<embl.ini>).

Only appropriate for full-chain queries. Otherwise, see L<run>

=cut
sub query {
    my ($pdbid, $chainid) = @_;
    my $db = $config->val('cofm', 'db') || "trans_1_5";
    my $dbh = dbconnect(-db=>$db) or return undef;
    # Static handle, prepare it only once
    our $sth;
    $sth ||= $dbh->prepare("select cofm.Cx,cofm.Cy,cofm.Cz," .
                           "cofm.Rg,entity.file,entity.description " .
                           "from cofm, entity " .
                           "where cofm.id_entity=entity.id and " .
                           "(entity.acc=? or entity.acc=?)");
    unless ($sth) {
        carp $dbh->errstr, "\n";
        return undef;
    }

    # Check PDB and PQS structures
    my $pdbstr = "pdb|$pdbid|$chainid";
    my $pqsstr = "pqs|$pdbid|$chainid";
    if (! $sth->execute($pdbstr, $pqsstr)) {
        carp $sth->errstr, "\n";
        return undef;
    }

    # ($x, $y, $z, $rg, $file, $descriptor);
    return $sth->fetchrow_array();
} # query


################################################################################
=head2 run

 Title   : run
 Usage   : my (@xyz, $rg, $file, $descriptor) = SBG::CofM::run($dom);
 Function: Computes centre-of-mass and radius of gyration of STAMP domain
 Example : my (@xyz, $rg, $file, $descriptor) = SBG::CofM::run($dom);
 Returns : XYZ coordinates, radius of gyration, path to file, STAMP descriptor
 Args    : L<SBG::Domain>

Runs external B<cofm> appliation. Must be in your environment's B<$PATH>

'descriptor' and 'pdbid' (or 'stampid') must be defined in the L<SBG::Domain>

=cut
sub run {
    my $dom = shift;
    # $dom->descriptor and $dom->pdbid must exist
    # Call ->pdbid first, as it might figure out and set the descriptor too
    return unless $dom && $dom->pdbid && $dom->descriptor;

    # Print the PDB ID, rather than the label, since cofm needs to find template
    my ($tfh, $path) = tempfile();
    my $io = new SBG::DomainIO(-fh=>$tfh);
    $io->write($dom, -id=>'pdbid');
    $io->flush;
    unless (-s $path) {
        carp "Failed to write Domain to $path\n";
        return;
    }

    # NB the -v option is necessary if you want the filename of the PDB file
    my $cofm = $config->val('cofm','executable') || 'cofm';
    my $cmd = "$cofm -f $path -v |";
    my $cofmfh;
    unless (open $cofmfh, $cmd) {
        carp "Failed: $cmd : $!\n";
        return undef;
    }

    my ($x, $y, $z);
    my $rg;
    my $file;
    my $descriptor;
    while (<$cofmfh>) {
        if (/^Domain\s+\S+\s+(\S+)/i) {
            $file = $1;
        } elsif (/^\s+chain\s+(\S+)/i) {
            $descriptor = "CHAIN $1";
        } elsif (/^\s+from\s+([a-zA-Z_])\s+(\d+)\s+to\s+([a-zA-Z_])\s+(\d+)/i) {
            $descriptor = "$1 $2 _ to $3 $4 _";
        } elsif (/^REMARK Domain/) {
            my @a = quotewords('\s+', 0, $_);
            ($rg, $x, $y, $z) = ($a[10], $a[16], $a[17], $a[18]);
        }
    }

    return ($x, $y, $z, $rg, $file, $descriptor);

} # run


################################################################################
=head2 get_cofm

 Title   : get_cofm
 Usage   : get_cofm($dom)
 Function: Sets the center of mass of an L<SBG::Domain>
 Example : get_cofm($dom)
 Returns : The $dom, now containing $dom->cofm;
 Args    : L<SBG::Domain>

Gets centre-of-mass of an SBG::Domain.

If the Domain is an entire chain, the database cache is queried first. Otherwise
cofm is run locally, if available. 

B<cofm> must be in your PATH, or defined in the B<embl.ini> file

The DB cache stores uppercase PDB IDs. The B<cofm> program will accept any case.

=cut
sub get_cofm {
    my $dom = shift;
    # $dom->descriptor and $dom->pdbid must exist
    # Call ->pdbid first, as it might figure out and set the descriptor too
    return unless $dom && $dom->pdbid && $dom->descriptor;

    my @fields;
    my $pdbid = uc $dom->pdbid;
    my $desc = $dom->descriptor;

    # If descriptor contains just a chain, try the cache first;
    if ($desc =~ /^CHAIN ([a-zA-Z_])$/) {
        my $chainid = $1;
        @fields = query($pdbid, $chainid);
    }

    # Couldn't get from DB, try running computation locally
    @fields or @fields = run($dom);

    unless (@fields) {
        carp "Cannot get centre-of-mass for ${pdbid} ${desc}\n";
        return undef;
    }
    my ($x, $y, $z, $rg, $file, $descriptor) = @fields;

    # Update
    $dom->cofm($x, $y, $z);
    $dom->rg($rg);
    # Don't overwrite existing
    $dom->file || $dom->file($file);
    # Should be equal already 
    unless ($dom->descriptor eq $descriptor) { 
        carp "$descriptor != " . $dom->descriptor . "\n";
    }
    return $dom;

} # get_cofm


################################################################################
1;
