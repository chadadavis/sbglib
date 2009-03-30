#!/usr/bin/env perl

=head1 NAME

SBG::STAMP - Computes STAMP centre-of-mass of an SBG::Domain

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
use base qw/Exporter/;

our @EXPORT_OK = qw(do_stamp sorttrans stamp pickframe gtransform superpose pdbc);

use strict;
use warnings;

use File::Temp qw(tempfile tempdir);
use IO::String;
use Data::Dumper;
use List::MoreUtils qw/mesh/;


use SBG::Transform;
use SBG::Domain;
use SBG::DomainIO;
use SBG::List qw(reorder);
use SBG::Config qw/config/;
use SBG::Log;


################################################################################

# TODO use Cache::FileCache
# Lazy initialisation of directories later ...
our $tmpdir;
our $cachedir;


################################################################################
=head2 transform

 Function: Converts an array of L<SBG::Domain>s to a PDB file
 Example :
 Returns : Path to PDB file, if successful
 Args    :
           doms arrayref of Domain's
           in path to Domain file
           out path to PDB file to create (otherwise temp file)

=cut
sub gtransform {
    my (%o) = @_;
    _init_tmp();
    my $ioin;
    # If no input domain file given, process given domains
    unless ($o{in}) {
        my $doms = $o{doms};
        $logger->debug("transform'ing domains: @$doms");
        return unless @$doms;
        $ioin = new SBG::DomainIO(tempfile=>1);
        $ioin->write($_) for @$doms;
    }
    $o{in} = $ioin->file;
    # Output PDB file
    my $ioout = new File::Temp(
        TEMPLATE=>'transform_XXXXX', DIR=>$tmpdir, SUFFIX=>'.pdb') unless $o{out};
    $o{out} ||= $ioout->filename;
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



################################################################################
=head2 superpose

 Function: Provides L<SBG::Transform> required to put $fromdom onto $ontodom
 Example :
 Returns : L<SBG::Transform>
 Args    : 
           fromdom
           ontodom

Does not modify/transform $fromdom.

If a L<SBG::Domain> already has a non-identity L<SBG::Transform>, it is not
considered here. I.e. the transformation will be the one that places the native
orientation of $fromdom onto the native orientation of $ontodom.

You will still need to then transform $fromdom.

=cut
sub superpose {
    my ($fromdom, $ontodom, %ops) = @_;
    $ops{'cache'} = 1 unless defined $ops{'cache'};
    $logger->trace("$fromdom onto $ontodom");

    if ($fromdom eq $ontodom) {
        $logger->trace("Identity");
        return new SBG::Transform();
    }

    # Check database cache
    # Useless, if we need Sc and seqID and all those meta-data
#     my $trydb = superpose_query($fromdom, $ontodom);
#     return $trydb if $trydb;

    # Check local disk cache
    my $cached = cacheget($fromdom, $ontodom) if $ops{'cache'};
    if (defined $cached) {
        if ($cached) {
            # Positive cache hit
            return $cached;
        } else {
            # Negative cache hit
            return;
        }
    }

    # Otherwise, try locally
    return superpose_local($fromdom, $ontodom, %ops);

} # superpose


################################################################################
=head2 superpose_local

 Function: run stamp locally, to do superposition of one domain onto another
 Example :
 Returns : L<SBG::Transform>
 Args    :


=cut
sub superpose_local {
    my ($fromdom, $ontodom, %ops) = @_;
    $ops{'cache'} = 1 unless defined $ops{'cache'};
    $logger->trace("$fromdom onto $ontodom");

    my ($doms, $fields) = do_stamp($fromdom, $ontodom);
    unless (@$doms) {
        # Cannot be STAMP'd. Add to negative cache
        cacheneg($fromdom,$ontodom);
        return;
    }

    # Reorder @doms based on the order of $fromdom, $ontodom
    my $ordered = reorder($doms, 
                          [ $fromdom->id, $ontodom->id],
                          sub { $_->id });
    
    # Want transformation relative to $ontodom
    # I.e. applying the resulting transformation to $fromdom results in $ontodom
    # The *absolute* transformation, that puts [0] into frame-of-ref of [1]
    my ($from, $to) = @$ordered;
    my $trans = $from->transformation->relativeto($to->transformation);


    # Store the meta data directly in this object
    # TODO DES bad style doing this here
    $trans->{$_} = $fields->{$_} for keys %$fields;

    # Set from's transformation to be the one that's relative to to's
    $from->transformation($trans);
    # Reset to's transform (to the identity)
    $to->transformation(new SBG::Transform);
    $logger->debug("Transformation: ", $fromdom->id, ' ', $ontodom->id, "\n$trans");    

    # Positive cache
    cachepos($from, $to) if $ops{'cache'};
    return $trans;

} # superpose_local



sub _dbconnect {
    my ($db) = @_;
    our $dbh;
    return $dbh if $dbh;
    $db ||= config()->val('trans', 'db') || "trans_1_4";
    my $host = config()->val(qw/trans host/);
    my $dbistr = "dbi:mysql:dbname=$db";
    $dbistr .= ";host=$host" if $host;
    $dbh = DBI->connect($dbistr);
    return $dbh;
}


# Takes two domain objects
sub superpose_query {
    my ($fromdom, $ontodom) = @_;
    $logger->trace("$fromdom onto $ontodom");
    return unless 
        $fromdom && $fromdom->wholechain &&
        $ontodom && $ontodom->wholechain;

    my $dbh = _dbconnect();

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
        return;
    }

    my $pdbstr1 = 'pdb|' . uc($fromdom->pdbid) . '|' . $fromdom->wholechain;
    my $pdbstr2 = 'pdb|' . uc($ontodom->pdbid) . '|' . $ontodom->wholechain;

    if (! $trans_sth->execute($pdbstr1)) {
        $logger->error($trans_sth->errstr);
        return;
    }
    my ($domset1, $transstr1) = $trans_sth->fetchrow_array();
    if (! $trans_sth->execute($pdbstr2)) {
        $logger->error($trans_sth->errstr);
        return;
    }
    my ($domset2, $transstr2) = $trans_sth->fetchrow_array();
    $logger->debug("domset $domset1 == domset $domset2 ?");
    unless ($domset1 && $domset2 && $domset1 == $domset2) {
        $logger->info("No transform between ",
                      "$pdbstr1($domset1) and $pdbstr2($domset2)");
        return;
    }

    my $trans1 = new SBG::Transform(string=>$transstr1);
    my $trans2 = new SBG::Transform(string=>$transstr2);
    # Returns a new Transform
    return $trans1->relativeto($trans2);

} # superpose_query


sub _cache_file {
    my ($fromdom, $ontodom) = @_;
    _init_cache();
    my $file = $cachedir . '/' . $fromdom->id . '-' . $ontodom->id . '.ntrans';
    $logger->trace("Cache: $file");
    return $file;
}

sub cacheneg {
    my ($fromdom, $ontodom) = @_;
    $logger->trace();
    my $file = _cache_file($fromdom, $ontodom);
    my $fh;
    open $fh, ">$file";
    # But write nothing ...
}

# Trans is the Transformation object to be contained in the From domain that
# would superpose it onto the Onto domain.
sub cachepos {
    my ($fromdom, $ontodom) = @_;
    $logger->trace();
    my $file = _cache_file($fromdom, $ontodom);
    my $io = new SBG::IO(file=>">$file");
    # STAMP scores, etc.
    $io->write($fromdom->transformation->headers);
    # Write onto domain (has no transform, it's the reference);
    $io->write($ontodom->asstamp);
    # Write from domain (has the transform)
    $io->write($fromdom->asstamp);
    # Succesful if the file exists and is not empty
    return -s $file;
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
            return new SBG::Transform(file=>$file);
        } else {
            $logger->debug("Negative cache hit");
            return 0;
        }
    } else {
        $logger->debug("Cache miss");
        return;
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
    my @dom_ids = map { $_->id } @doms;
    my %domains = map { $_->id => $_ } @doms;
    $logger->debug("Domain IDs:@dom_ids");
    # No. domains tried as a probe
    my %tried;
    # Domains in current set
    my %current;
    # Resulting domains
    my @all_doms;
    # Number of disjoint domain sets
#     my $n_disjoins=0;

    # The hash of domains stamp() identifies as keep'able
    my $keep;
    # The STAMP scores
    my $fields;
    # Temp prefix for scan file
    my $tp;

    # While there are domains not-yet-tried
    while (keys(%tried) < @dom_ids && keys(%current) < @dom_ids) {

        # Get next not-yet-tried probe domain, preferably from current set
        my ($probe, $in_disjoint) = _next_probe(\@dom_ids, \%current, \%tried);
        last unless $probe;
        $tried{$probe}=1;

        # Write probe domain to file
        my $ioprobe = new SBG::DomainIO(tempfile=>1);
        my $tmp_probe = $ioprobe->file;
        $ioprobe->write($domains{$probe}, trans=>0);
        $ioprobe->close;
        $logger->debug("probe:$probe");
        # Write other domains to single file
        my $iodoms = new SBG::DomainIO(tempfile=>1);
        my $tmp_doms = $iodoms->file;
        foreach my $dom (@dom_ids) {
            if((!defined($current{$dom})) && ($dom ne $probe)) {
                $iodoms->write($domains{$dom}, trans=>0);
                $logger->debug("a domain:$dom (",
                               $domains{$dom}->uniqueid . ')');
            }
        }
        $iodoms->close;
        # Run stamp and add %keep to %current
        # TODO DES Need to get more data back from stamp() here
        ($keep, $fields, $tp) = stamp($tmp_probe, $tmp_doms);
        $current{$_} = 1 for keys %$keep;

        # Sort transformations, if there were any
        my @keep_doms;
        @keep_doms = sorttrans($keep, prefix=>$tp) if keys(%$keep);
        unlink "${tp}.scan" unless $File::Temp::KEEP_ALL;
        # Unless this only contains the probe, results are useful
        unless ( @keep_doms == 1 && $keep_doms[0]->id eq $probe ) {
            push @all_doms, @keep_doms;
            # Count number of disjoint sets
#             $n_disjoins++ if $in_disjoint;
        }

    } # while
    return \@all_doms, $fields;

} # do_stamp


################################################################################
=head2 pickframe

 Function: Sets all domains to be relative to given L<SBG::Domain>
 Example : pickframe($mydomain, @other_domains);
 Returns : NA
 Args    : Array of L<SBG::Domain>

NB This actually changes the transformations of all the domains given.

TODO test this

=cut
sub pickframe {
    my ($dom, @others) = @_;

    foreach my $o (@others) {
        my $trans = $o->transformation->relativeto($dom->transformation);
        $o->transform($trans);
    }

    # Finally, the frame of reference gets the identity transformation
    $dom->transformation(new SBG::Transform);

} # pickframe



################################################################################
=head2 stamp

 Function: Returns IDs of the domains to keep, based on Sc cutoff
 Example : 
 Returns : 
 Args    : 

For stamp parameters, see: 

 http://www.compbio.dundee.ac.uk/manuals/stamp.4.2/node36.html

=cut
sub stamp {
    my ($tmp_probe, $tmp_doms, $just1) = @_;
    our $com;
    $com ||= _stamp_config();
    my $tp = _tmp_prefix();
    $com .= join(' ', ' ',
                 "-l $tmp_probe",  # probe (i.e. query) sequence
                 "-d $tmp_doms",   # database domains
                 "-prefix", $tp->filename, # tmp path to scan file (prefix.scan)
        );

    $logger->trace("\n$com");
    open my $fh,"$com |";
    unless ($fh) {
        $logger->error("Error running stamp:\n$com");
        return;
    }

    # Parse out the 'Scan' lines from stamp output
    our @keys = qw/Domain1 Domain2 Fits Sc RMS Len1 Len2 Align Fit Eq Secs I S P/;
    # Hash key names to stamp scores
    my %fields;

    my %KEEP = ();

    while(<$fh>) {
        next if /skipped/ || /error/ || /missing/;
        next unless /^Scan/;
        chomp;
        $logger->trace($_);

        my @t = split(/\s+/);
        shift @t; # Loose the 'Scan' header
        # Hash @keys to @t
        %fields = List::MoreUtils::mesh @keys, @t;
        $logger->trace("fields:", join(' ', %fields));
        # If the incoming domain had a trans, but it doesn't afterward, the name
        # can be different, remove qualifier:
        $fields{'Domain1'} =~ s/-0x.*//;
        $fields{'Domain2'} =~ s/-0x.*//;
        
        unless ($fields{'Fits'} > 0) {
            $logger->info("No fits");
            next;
        }
        # Yes, keep these domains
        $KEEP{ $fields{'Domain1'} } = 1;
        $KEEP{ $fields{'Domain2'} } = 1;

        return \%fields if $just1;
    }
    return \%KEEP, \%fields, $tp;
} # stamp


sub _stamp_config {

    # Get config setttings
    my $stamp = config()->val('stamp', 'executable') || 'stamp';
    # Number of fits (residues?) that were performed
    my $minfit = config()->val('stamp', 'minfit') || 30;
    # Min Sc value to accept
    my $scancut = config()->val('stamp', 'scancut') || 2.0;

    my $stamp_pars = config()->val('stamp', 'params') || join(' ',
        '-n 2',         # number of fits 
        '-slide 5',     # query slides every 5 AAs along DB sequence
        '-s',           # scan mode: only query compared to each DB sequence
        '-secscreen F', # Do not perform initial secondary structure screen
        '-opd',         # one-per-domain: just one hit per query domain
        );

    $stamp_pars .= join(' ', ' ',
        "-minfit $minfit",
        "-scancut $scancut", 
        );

    my $com = "$stamp $stamp_pars";
    $logger->trace("\n$com");
    return $com;
}


# tempfile unlinked when object leaves scope (garbage collected)
sub _tmp_prefix {
    _init_tmp();
    my $tmp = new File::Temp(TEMPLATE=>"scan_XXXXX", DIR=>$tmpdir);
    return $tmp;
}


################################################################################
=head2 sorttrans

 Function: Run sorttrans (parse the $tmp_scan file)
 Example : 
 Returns : array of L<SBG::Domain> 
 Args    : 
          sort Sc
          cutoff 0.5

NB: might return just the probe. You need to check

=cut
sub sorttrans {
    my ($KEEP, %o) = @_;
    $o{sort} ||= 'Sc';
    $o{cutoff} ||= 0.5;
    $o{prefix} ||= 'stamp_trans';
    $logger->trace("keep:" . join(' ',keys(%$KEEP)) . " $o{sort}:$o{cutoff}");

    # File containing STAMP scan results
    my $tmp_scan = "$o{prefix}.scan";
    my $sorttrans = config()->val("stamp", "sorttrans") || 'sorttrans';
    my $params = "-i";
    my $com = join(' ', 
                   $sorttrans, $params,
                   "-f", $tmp_scan,
                   "-s", $o{sort}, $o{cutoff},
        );
    $logger->trace("\n$com");
    my $fh;
    unless (open($fh,"$com |")) {
        $logger->error("Failed:\n$com");
        return;
    }

    # Read all doms
    my $io = new SBG::DomainIO(fh=>$fh);
    my @doms;
    while (my $d = $io->read) {
        push(@doms, $d);
    }
    $io->close;
    $logger->trace("Re-read domains:@doms");

    my @theids  = map { $_->id } @doms;
    $logger->trace("Re-read IDs:@theids");
    $logger->trace("Looking for domains w/ IDs: " .  join(' ',keys(%$KEEP)));

    # Which domains are to be kept
    my @keep_doms = grep { defined($KEEP->{$_->id}) } @doms;
    $logger->debug("Kept:@keep_doms");
    return @keep_doms;

} # sorttrans


################################################################################
=head2 _next_probe

 Function: Returns (probe, disjoint)
 Example : 
 Returns : 
 Args    : 

Disjoint==1 if not-yet-tried probe could not be found in %$current

=cut
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


sub _init_tmp {
    our $tmpdir;
    $tmpdir ||= config()->val(qw/tmp tmpdir/) || $ENV{TMPDIR} || '/tmp';
    mkdir $tmpdir unless -d $tmpdir;
}


sub _init_cache {
    our $cachedir;
    $cachedir ||= config()->val(qw/stamp cache/) || "$tmpdir/stampcache";
    mkdir $cachedir unless -d $cachedir;
}


################################################################################
1;

__END__


