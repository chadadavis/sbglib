#!/usr/bin/env perl

=head1 NAME

EMBL::CofM - Computes STAMP centre-of-mass of an EMBL::Domain

=head1 SYNOPSIS

use EMBL::CofM;

=head1 DESCRIPTION


=head1 Functions

Details on functions implemented here are described below.
Private internal functions are generally preceded with an _

=cut

################################################################################

package EMBL::CofM;
use EMBL::Root -base, -XXX;

use Carp;

use EMBL::DB;



################################################################################
=head2 fetch

 Title   : fetch
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :

Gets centre-of-mass of an EMBL::Domain.

If the Domain is an entire chain, the database cache is queried first. Otherwise
cofm is run locally, if available. ('cofm' must be in your PATH)

The DB cache stores uppercase PDB IDs. The cofm program will accept any case.

=cut

sub fetch{
    my $dom = shift;
    my $pdbid = uc $dom->pdbid;
    return unless $pdbid;

    # Upper-case PDB ID (for DB, but acceptable to cofm as well)
    my ($pdbid, $chainid) = $id =~ /(.{4})(.{1})/;
    $pdbid = uc $pdbid;

    # Defaults:
#     $self->file($pdbid);
#     $self->description("CHAIN $chainid");

    my @fields;
    # Try from DB:
    @fields = $self->query($pdbid, $chainid);
    # Couldn't get from DB, try running computation locally
    @fields or @fields = $self->run($pdbid, $chainid);

    unless (@fields) {
        print STDERR "Cannot get centre-of-mass for $pdbid$chainid\n";
        return undef;
    }

    my ($x, $y, $z, $rg, $file, $description) = @fields;

    return $self unless @fields;

    $self->id($id) if $id;
    # Dont' overwrite any previously labelled
    $self->label($id) if (!$self->label() && $id);
    $self->init($x, $y, $z) if ($x && $y && $z);
    $self->rg($rg) if $rg;
    $self->file($file) if $file;
    $self->description($description) if $description;

    return $self;
} # fetch


################################################################################
=head2 query

 Title   : query
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :

TODO use Config::IniFiles;

=cut
sub query {
    my ($pdbid, $chainid) = @_;
    $logger->debug("$pdbid, $chainid");

    my $dbh = dbconnect("pc-russell12", "trans_1_5") or return undef;
    # Static handle, prepare it only once
    our $sth;
    $sth ||= $dbh->prepare("select cofm.Cx,cofm.Cy,cofm.Cz," .
                           "cofm.Rg,entity.file,entity.description " .
                           "from cofm, entity " .
                           "where cofm.id_entity=entity.id and " .
                           "(entity.acc=? or entity.acc=?)");
    unless ($sth) {
        $logger->error($dbh->errstr);
        carp $dbh->errstr;
        return undef;
    }

    # Check PDB and PQS structures
    my $pdbstr = "pdb|$pdbid|$chainid";
    my $pqsstr = "pqs|$pdbid|$chainid";

    if (! $sth->execute($pdbstr, $pqsstr)) {
        $logger->error($sth->errstr);
        carp $sth->errstr;
        return undef;
    }

    return $sth->fetchrow_array();
} # query


################################################################################
=head2 run

 Title   : run
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :

Run external cofm. Must be in your environment's $PATH

TODO update DB with cached results (if whole chain)

TODO Ini file to define path to cofm

=cut
sub run {
    my ($pdbid, $chainid) = @_;
    $logger->debug("$pdbid, $chainid");

    my $cofm = $inicfg->val('cofm','executable') || 'cofm';

    # TODO DES should be it's own class
    # Run pdbc to get a STAMP DOM file
    my (undef, $path) = tempfile();
    my $cmd;
    $cmd = "pdbc -d ${pdbid}${chainid} > ${path}";
    # NB checking system()==0 fails, even when successful
    system($cmd);
    # So, just check that file was written to instead
    unless (-s $path) {
        print STDERR "Failed: $cmd : $!\n";
        return undef;
    }
    # Pipe output back here into Perl
    # NB the -v option is necessary to get the filename of the PDB file
    $cmd = "$cofm -f $path -v |";
    my $fh;
    unless (open $fh, $cmd) {
        print STDERR "Failed: $cmd : $!\n";
        return undef;
    }

    my ($x, $y, $z, $rg, $file, $description);
    while (<$fh>) {
#         print STDERR "$_";
        if (/^Domain\s+\S+\s+(\S+)/i) {
            $file = $1;
#             print STDERR "\tGOT file:$file:\n";
        } elsif (/^\s+chain\s+(\S+)/i) {
            $description = "CHAIN $1";
#             print STDERR "\tGOT description:$description:\n";
        } elsif (/^REMARK Domain/) {
            my @a = quotewords('\s+', 0, $_);
#             print STDERR "quotewords:@a:\n";
            ($rg, $x, $y, $z) = ($a[10], $a[16], $a[17], $a[18]);
        }
    }

    return ($x, $y, $z, $rg, $file, $description);

} # fetchrun

################################################################################
1;

