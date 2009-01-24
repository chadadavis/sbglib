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

L<SBG::Domain> , L<SBG::DomainIO>

=cut

################################################################################

package SBG::STAMP;
use SBG::Root -base, -XXX;

# TODO DES don't need all of these
our @EXPORT = qw(do_stamp sorttrans stamp pickframe transform superpose pdb2img pdbc);

use warnings;
use File::Temp qw(tempfile tempdir);
use IO::String;
use Data::Dumper;

use SBG::Transform;
use SBG::Domain;
use SBG::DomainIO;
use SBG::DB;
use SBG::List qw(reorder);

################################################################################

our $cachedir;

BEGIN {

    $cachedir = $config->val('stamp', 'cache') || "/tmp/stampcache";
    mkdir $cachedir;
    $logger->debug("STAMP cache: $cachedir");

}

# -script - any additional options (string with newlines)
# -pdb
# -img
sub pdb2img {
    my (%o) = @_;
    SBG::Root::_undash %o;
    $o{pdb} or return;
    (undef, $o{img}) = tempfile(SUFFIX=>'.ppm') unless $o{img};
    $logger->trace("$o{pdb} => $o{img}");
    my $rasmol = $config->val('rasmol','executable') || 'rasmol';
    my $fh;
    my $cmd = "$rasmol -nodisplay >/dev/null";
#     my $cmd = "$rasmol -nodisplay ";
    $logger->trace($cmd);
    unless(open $fh, "| $cmd") {
        $logger->error("Failed: $cmd");
        return;
    }
    print $fh <<HERE;
load "$o{pdb}"
wireframe off
spacefill
color chain
HERE

    # Any additional options
    print $fh "$o{script}\n" if $o{script};

    print $fh <<HERE;
write "$o{img}"
exit
HERE

    # Need to explicitly close before checking for output file
    close $fh;
    unless (-s "$o{img}") {
        $logger->error("Rasmol failed to write: $o{img}");
        return;
    }
    return $o{img};
} # pdb2img
    

# Converts an array of L<SBG::Domain>s to a PDB file
# returns Path to PDB file, if successful
# -doms arrayref of Domain's
# -in path to Domain file
# -out path to PDB file to create (otherwise temp file)
sub transform {
    my (%o) = @_;
    SBG::Root::_undash(%o);
    my $doms = $o{doms};
    # Input file (domains/transformations)
    unless ($o{in}) {
        $logger->debug("transform'ing domains: @$doms");
        return unless @$doms;
        (undef, $o{in}) = tempfile;
        my $io = new SBG::DomainIO(-file=>">$o{in}");
        $io->write($_,-id=>'stampid') for @$doms;

    }
    # Output PDB file
    (undef, $o{out}) = tempfile(UNLINK=>0) unless $o{out};
    $logger->trace("Complex DOM file: $o{in}");
    $logger->trace("Complex PDB file: $o{out}");
    my $cmd = "transform -f $o{in} -g -o $o{out} >/dev/null";
    system($cmd);
    unless (-s $o{out}) {
        $logger->error("Failed:\n\t$cmd");
        return;
    }
    return $o{out};
} # transform


# TODO DOC
# Returns Transformation required to put $fromdom onto $ontodom
sub superpose {
    my ($fromdom, $ontodom) = @_;
    $logger->trace("$fromdom onto $ontodom");

    if ($fromdom->pdbid eq $ontodom->pdbid &&
        $fromdom->descriptor eq $ontodom->descriptor) {
        $logger->trace("Identity");
        return new SBG::Transform();
    }

    # Check database cache
    my $trydb = superpose_query($fromdom, $ontodom);
    return $trydb if $trydb;

    # Check local disk cache
    my $cached = cacheget($fromdom, $ontodom);
    if (defined $cached) {
        if ($cached) {
            # Positive cache hit
            return $cached;
        } else {
            # Negative cache hit
            return undef;
        }
    }

    # Otherwise, try locally
    return superpose_local($fromdom, $ontodom);

} # superpose

# NB STAMP doesn't work on Domains that already have a Transform
# This is for computing transforms on the native, not-yet-transformed PDB data
sub superpose_local {
    my ($fromdom, $ontodom) = @_;
    $logger->trace("$fromdom onto $ontodom");

    my @doms = do_stamp($fromdom, $ontodom);
    unless (@doms) {
        # Cannot be STAMP'd. Add to negative cache
        cacheneg($fromdom,$ontodom);
        return;
    }

    # Reorder @doms based on the order of $fromdom, $ontodom
    my $ordered = reorder(\@doms, 
                          [ $fromdom->stampid, $ontodom->stampid],
                          'stampid');
    
    # Want transformation relative to $ontodom
    # I.e. applying the resulting transformation to $fromdom results in $ontodom
    # The *absolute* transformation, that puts [0] into frame-of-ref of [1]
    my ($from, $to) = @$ordered;
    my $trans = $from->transformation->relativeto($to->transformation);
    $logger->debug("Transformation:\n$trans");    

    # Positive cache
    cachepos($fromdom,$ontodom,$trans);
    return $trans;

} # superpose_local


# Takes two domain objects
sub superpose_query {
    my ($fromdom, $ontodom) = @_;
    $logger->trace("$fromdom onto $ontodom");
    return unless 
        $fromdom && $fromdom->onechain &&
        $ontodom && $ontodom->onechain;

    my $db = $config->val('trans', 'db') || "trans_1_4";
    my $dbh = dbconnect(-db=>$db) or return undef;
    # Static handle, prepare it only once
    our $trans_sth;
    $trans_sth ||= $dbh->prepare(
        "SELECT trans.id_domset, trans.trans " .
        "FROM trans, entity where " .
        "trans.id_entity=entity.id and " .
        "entity.acc=?"
        );
    unless ($trans_sth) {
        $logger->error($dbh->errstr);
        return undef;
    }

    my $pdbstr1 = 'pdb|' . uc($fromdom->pdbid) . '|' . $fromdom->chainid;
    my $pdbstr2 = 'pdb|' . uc($ontodom->pdbid) . '|' . $ontodom->chainid;

    if (! $trans_sth->execute($pdbstr1)) {
        $logger->error($trans_sth->errstr);
        return undef;
    }
    my ($domset1, $transstr1) = $trans_sth->fetchrow_array();
    if (! $trans_sth->execute($pdbstr2)) {
        $logger->error($trans_sth->errstr);
        return undef;
    }
    my ($domset2, $transstr2) = $trans_sth->fetchrow_array();
    $logger->debug("domset $domset1 == domset $domset2 ?");
    unless ($domset1 && $domset2 && $domset1 == $domset2) {
        $logger->info("No transform between ",
                      "$pdbstr1($domset1) and $pdbstr2($domset2)");
        return;
    }

    my $trans1 = new SBG::Transform(-string=>$transstr1);
    my $trans2 = new SBG::Transform(-string=>$transstr2);
    # Returns a new Transform
    return $trans1->relativeto($trans2);

} # superpose_query


sub _cache_file {
    my ($fromdom, $ontodom) = @_;
    my $file = "$cachedir/" . 
        join('-', $fromdom->pdbid, $fromdom->_descriptor_short,
             $ontodom->pdbid, $ontodom->_descriptor_short) .
             ".trans";
    $logger->trace("Cache: $file");
    return $file;
}

sub cacheneg {
    my ($fromdom, $ontodom) = @_;
    $logger->trace();
    my $file = _cache_file($fromdom, $ontodom);
    my $io = new SBG::DomainIO(-file=>">$file");
    # But write nothing ...
}

# Trans is the Transformation object to be contained in the From domain that
# would superpose it onto the Onto domain.
sub cachepos {
    my ($fromdom, $ontodom, $trans) = @_;
    $logger->trace();
    my $file = _cache_file($fromdom, $ontodom);
    my $io = new SBG::IO(-file=>">$file");
    $io->write($trans,-id=>'stampid');
}

# Returns:
# miss: undef
# neg hit: 0
# pos hit: Domain with Transform
sub cacheget {
    my ($fromdom, $ontodom) = @_;
    $logger->trace("$fromdom onto $ontodom");
    my $file = _cache_file($fromdom, $ontodom);
    my $io;
    if (-r $file) {
        # Cache hit
        if (-s $file) {
            $logger->debug("Positive cache hit");
            return new SBG::Transform(-file=>$file);
        } else {
            $logger->debug("Negative cache hit");
            return 0;
        }
    } else {
        $logger->debug("Cache miss");
        return undef;
    }
} # cacheget


# Inputs are arrayref of L<SBG::Domain>s
# TODO caching, based on what? (PDB/PQS ID + descriptor)
# L<SBG::Domain> objects returned are newly created
# Original L<SBG::Domain>s not modified
# NB this superposes native PDB structures, or segments of them. 
# If a Domain has already been transformed to a new location in space, that will
# *not* be taken into consideration here.
sub do_stamp {
    my (@doms) = @_;
    $logger->trace("@doms");
    unless (@doms > 1) {
        $logger->error("Need two or more domains to STAMP");
        return;
    }
    # Index label's
    my @dom_ids = map { $_->stampid } @doms;
    my %domains = map { $_->stampid => $_ } @doms;
    $logger->debug("Domain IDs:@dom_ids");
    # No. domains tried as a probe
    my %tried;
    # Domains in current set
    my %current;
    # Resulting domains
    my @all_doms;
    # Number of disjoint domain sets
#     my $n_disjoins=0;

    # While there are domains not-yet-tried
    while (keys(%tried) < @dom_ids && keys(%current) < @dom_ids) {

        # Get next not-yet-tried probe domain, preferably from current set
        my ($probe, $in_disjoint) = _next_probe(\@dom_ids, \%current, \%tried);
        last unless $probe;
        $tried{$probe}=1;

        # Write probe domain to file
        my (undef, $tmp_probe) = tempfile();
        my $ioprobe = new SBG::DomainIO(-file=>">$tmp_probe");
        $ioprobe->write($domains{$probe},-id=>'stampid');
        $logger->debug("probe:$probe");
        # Write other domains to single file
        my (undef, $tmp_doms) = tempfile();
        my $iodoms = new SBG::DomainIO(-file=>">$tmp_doms");
        foreach my $dom (@dom_ids) {
            if((!defined($current{$dom})) && ($dom ne $probe)) {
                $iodoms->write($domains{$dom},-id=>'stampid');
                $logger->debug("a domain:$dom (",
                               $domains{$dom}->stampid . ')');
            }
        }

        # Run stamp and add %keep to %current
        my %keep = stamp($tmp_probe, $tmp_doms);
        $current{$_} = 1 for keys %keep;

        # Sort transformations
        my @keep_doms = sorttrans(\%keep);
        # Unless this only contains the probe, results are useful
        unless ( @keep_doms == 1 && $keep_doms[0]->label eq $probe ) {
            push @all_doms, @keep_doms;
            # Count number of disjoint sets
#             $n_disjoins++ if $in_disjoint;
        }

    } # while
    return @all_doms;

} # do_stamp


#     pickframe('2nn6b', @keep_doms);
# NB STAMP uses lowercase chain IDs. Need to change IDs for pickframe?
# $key is a regular expression, case insensitive

# NB This actually changes the transformations of all the domains given
# This should be called 'setframe', but we'll stick to STAMP conventions
# NB This hasn't been tested and is suspected of being broken!
sub pickframe {
    my ($key, @doms) = @_;
    $logger->trace("key:$key in ", join(',',@doms));

    # Find the domain with the given label
    my ($ref) = grep { $_->stampid =~ /$key/i } @doms;
    $logger->debug("Reference: $ref\n", $ref->transformation);
    unless ($ref) {
        $logger->error("Cannot find domain: $key");;
        return;
    }

    # Get it's transformation matrix, the inverse that is
    my $inv = $ref->transformation->matrix->inv;
    # Multiply every matrix of every domain by this inverse
    foreach (@doms) {
        my $m = $_->transformation->matrix;
        $m .= $inv x $m;
    }
} # pickframe



# Returns IDs of the domains to keep, based on Sc cutoff
sub stamp {
    my ($tmp_probe, $tmp_doms) = @_;
    $logger->trace("probe: $tmp_probe domains: $tmp_doms");
    # Get config setttings
    my $stamp = $config->val('stamp', 'executable') || 'stamp';
    my $min_fit = $config->val('stamp', 'min_fit') || 30;
    my $min_sc = $config->val('stamp', 'sc_cut') || 2.0;
    my $stamp_pars = $config->val('stamp', 'params') || 
        '-n 2 -slide 5 -s -secscreen F -opd';
    $stamp_pars .= " -scancut $min_sc";
    my $tmp_prefix = $config->val('stamp', 'prefix') || 'stamp_trans';

    my $com = join(' ', $stamp, $stamp_pars,
                "-l $tmp_probe",
                "-prefix $tmp_prefix",
                "-d $tmp_doms");
    $logger->trace("\n$com");
    my $fh;
    unless (open $fh,"$com |") {
        $logger->error("Error running stamp:\n$com");
        return;
    }

    # Parse out the 'Scan' lines from stamp output
    my %KEEP = ();
    while(<$fh>) {
        next if /skipped/ || /error/ || /missing/;
        next unless /^Scan/;
        chomp;
        $logger->trace($_);
        my @t = split(/\s+/);
        my $id1 = $t[1];
        my $id2 = $t[2];
        my $sc = $t[4];
        my $nfit = $t[9];
        if(($sc > 0.5) && (($sc>=$min_sc) || ($nfit >= $min_fit))) {
            $KEEP{$id1}=1;
            $KEEP{$id2}=1;
        }
    }
    return %KEEP;
} # stamp


# Run sorttrans (parse the $tmp_scan file)
# -sort Sc
# -cutoff 0.5
# Returns array of L<SBG::Domain> 
# NB: might be just the probe. You need to check
sub sorttrans {
    my ($KEEP, %o) = @_;
    $o{-sort} ||= 'Sc';
    $o{-cutoff} ||= 0.5;
    $logger->trace("keep:" . join(' ',keys(%$KEEP)) . " $o{-sort}:$o{-cutoff}");
    my $tmp_prefix = $config->val('stamp', 'prefix') || 'stamp_trans';
    # File containing STAMP scan results
    my $tmp_scan = "${tmp_prefix}.scan";

    my $sorttrans = $config->val("stamp", "sorttrans") || 'sorttrans';
    my $params = "-i";
    my $com = join(' ', $sorttrans, $params,
                   "-f", $tmp_scan,
                   "-s", $o{-sort}, $o{-cutoff},
        );
    $logger->trace("\n$com");
    my $fh;
    unless (open($fh,"$com |")) {
        $logger->error("Failed:\n$com");
        return;
    }

    # Read all doms
    my $io = new SBG::DomainIO(-fh=>$fh);
    my @doms;
    while (my $d = $io->read) {
        push(@doms, $d);
    }
    $logger->trace("Re-read domains:@doms");

    # Which domains are to be kept
    my @keep_doms = grep { defined($KEEP->{$_->stampid}) } @doms;
    $logger->debug("Kept:@keep_doms");
    return @keep_doms;

} # sorttrans


# Returns (probe, disjoint)
# Disjoint==1 if not-yet-tried probe could not be found in %$current
sub _next_probe {
    my ($all, $current, $tried) = @_;
    my $probe;

    # Get another probe from the current set, not yet tried
    ($probe) = grep { ! defined($tried->{$_}) } keys %$current;
    return ($probe, 0) if $probe;

    # Get another probe from anywhere (i.e. unconnected now), not yet tried
    ($probe) = grep { ! defined($tried->{$_}) } @$all;
    return ($probe, 1) if $probe;

    $logger->error("Out of probes");
    return;
} # _next_probe


################################################################################
=head2 pdbc

 Title   : pdbc
 Usage   : pdbc('2nn6');
           pdbc('2nn6', 'A', 'B');
           pdbc('2nn6A', 'F');
 Function: Runs STAMP's pdbc and opens its output as the internal input stream.
 Example : my $domio = pdbc('2nn6');
           my $dom = $domio->read();
           # or all in one:
           my $first_dom = pdbc(-pdbid=>'2nn6')->read();
 Returns : $self (success) or undef (failure)
 Args    : @ids - begins with one PDB ID, followed by any number of chain IDs

Depending on the configuration of STAMP, domains may be searched in PQS first.

 my $io = new SBG::DomainIO;
 $io->pdbc('2nn6');
 # Get the first domain (i.e. chain) from 2nn6
 my $dom = $io->read;

=cut
sub pdbc {
    my $str = join("", @_);
    return unless $str;
    my (undef, $path) = tempfile();
    my $cmd;
    $cmd = "pdbc -d $str > ${path}";
    $logger->trace($cmd);
    # NB checking system()==0 fails, even when successful
    system($cmd);
    # So, just check that file was written to instead
    unless (-s $path) {
        $logger->error("Failed:\n\t$cmd\n\t$!");
        return 0;
    }
    return new SBG::DomainIO(-file=>"<$path");

} # pdbc


################################################################################
1;

__END__


