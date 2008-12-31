#!/usr/bin/env perl

=head1 NAME

EMBL::CofM - Computes STAMP centre-of-mass of an EMBL::Domain

=head1 SYNOPSIS

 use EMBL::CofM;

=head1 DESCRIPTION

Looks up cached results in database, if available. This is only the case for
full chains. Otherwise, cofm is executed anew.

Also fetches radius of gyration of the centre of mass.

=head1 SEE ALSO

L<EMBL::Domain>

=cut

################################################################################

package EMBL::STAMP;
use EMBL::Root -base, -XXX;

# TODO DES don't need all of these
our @EXPORT = qw(do_stamp stampfile sorttrans stamp reorder pickframe next_probe do_stamp);

use warnings;
use Carp;
use File::Temp qw(tempfile);
use IO::String;
use Data::Dumper;

use EMBL::Transform;
use EMBL::Domain;
use EMBL::DomainIO;

################################################################################


# TODO DES
sub transform {
    my ($transfile) = @_;

    system("transform -f $transfile -g -o out.pdb") == 0 or
        die("$!");
    rename "out.pdb", "in.pdb";

}


# returns EMBL::Transform
# Transformation will be relative to fram of reference of destdom
sub stampfile {
    my ($srcdom, $destdom) = @_;

    # STAMP uses lowercase chain IDs
    $srcdom = lc $srcdom;
    $destdom = lc $destdom;

    if ($srcdom eq $destdom) {
        # Return identity
        return new EMBL::Transform;
    }

    print STDERR "\tSTAMP ${srcdom}->${destdom}\n";
    my $dir = "/tmp/stampcache";
    `mkdir /tmp/stampcache` unless -d $dir;
#     my $file = "$dir/$srcdom-$destdom-FoR.csv";
    my $file = "$dir/$srcdom-$destdom-FoR-s.csv";

    if (-r $file) {
        print STDERR "\t\tCached: ";
        if (-s $file) {
            print STDERR "positive\n";
        } else {
            print STDERR "negative\n";
            return undef;
        }
    } else {
        my $cmd = "./transform.sh $srcdom $destdom $dir";
        $file = `$cmd`;
    }

    my $trans = new EMBL::Transform();
    unless ($trans->loadfile($file)) {
        print STDERR "\tSTAMP failed: ${srcdom}->${destdom}\n";
        return undef;
    }
    return $trans;
} 


# TODO DEL
# This is already in DomainIO
sub parsetrans {
    my ($transfile) = @_;
    open(my $fh, $transfile);
    my %all;
    $all{'copy'} = [];
    my @existing;
    while (<$fh>) {
        next if /^%/;
        if (/^(\S+) (\S+) \{ ([^\}]+)/) {
            $all{'file'} = $1;
            $all{'name'} = $2;
            $all{'dom'} = $3;
            # The last line here includes a trailing }
            $all{'transform'} = [ <>, <>, <> ];
        } elsif (/^(\S+) (\S+) \{ (.*?) \}/) {
            push @{$all{'copy'}}, $_;
        } else {
            print STDERR "?: $_";
        }
    }
    close $fh;
    return %all;
}


################################################################################



sub do_stamp {
    my ($doms) = @_;
    unless (@$doms > 1) {
        carp "Need at least two domains.\n";
        return;
    }
    # Index stampid's
    my @dom_ids = map { $_->stampid } @$doms;
    my %domains = map { $_->stampid => $_ } @$doms;

    # No. domains tried as a probe
    my %tried;
    # Domains in current set
    my %current;
    # Resulting domains
    my @all_doms;
    # Number of disjoint domain sets
#     my $n_disjoins=0;

    # Where there are domains not-yet-tried
    while (keys(%tried) < @dom_ids && keys(%current) < @dom_ids) {

        # Get next not-yet-tried probe domain, preferably from current set
        my ($probe, $in_disjoint) = next_probe(\@dom_ids, \%current, \%tried);
        last unless $probe;
        $tried{$probe}=1;

        # Write probe domain to file
        my (undef, $tmp_probe) = tempfile();
        my $ioprobe = new EMBL::DomainIO(-file=>">$tmp_probe");
        $ioprobe->write($domains{$probe});

        # Write other domains to single file
        my (undef, $tmp_doms) = tempfile();
        my $iodoms = new EMBL::DomainIO(-file=>">$tmp_doms");
        foreach my $dom (@dom_ids) {
            if((!defined($current{$dom})) && ($dom ne $probe)) {
                $iodoms->write($domains{$dom});
            }
        }

        # Run stamp and add %keep to %current
        my %keep = stamp($tmp_probe, $tmp_doms);
        $current{$_} = 1 for keys %keep;

        # Sort transformations
        my @keep_doms = sorttrans(\%keep);
        # Unless this only contains the probe, results are useful
        unless ( @keep_doms == 1 && $keep_doms[0]->stampid eq $probe ) {
            push @all_doms, @keep_doms;
            # Count number of disjoint sets
#             $n_disjoins++ if $in_disjoint;
        }

    } # while
    return @all_doms;

} # do_stamp



#     pickframe('2nn6b', \@keep_doms);
sub pickframe {
    my ($key, $doms) = @_;
    # Find the domain with the given stampid
    my ($ref) = grep { $_->stampid eq $key } @$doms;
    unless ($ref) {
        carp "Cannot find domain: $key\n";
        return;
    }
    # Get it's transformation matrix, the inverse that is
    my $inv = $ref->transformation->matrix->inv;
    # Multiply every matrix of every domain by this inverse
    foreach (@$doms) {
        my $m = $_->transformation->matrix;
        $m .= $inv x $m;
    }
} # pickframe


# Returns IDs of the domains to keep
sub stamp {
    my ($tmp_probe, $tmp_doms) = @_;

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
#     print STDERR "$com\n";
    my $fh;
    unless (open $fh,"$com |") {
        carp "Error running/reading $com\n";
        return;
    }

    # Parse out the 'Scan' lines from stamp output
    my %KEEP = ();
    while(<$fh>) {
        next if /skipped/ || /error/ || /missing/;
        next unless /^Scan/;
        chomp;
#         print STDERR "%",$_;
        my @t = split(/\s+/);
        my $id1 = $t[1];
        my $id2 = $t[2];
        my $sc = $t[4];
        my $nfit = $t[9];
        if(($sc > 0.5) && (($sc>=$min_sc) || ($nfit >= $min_fit))) {
            $KEEP{$id1}=1;
            $KEEP{$id2}=1;
#             print STDERR " ** ";
        }
#         print STDERR "\n";
    }
    return %KEEP;
} # stamp


# Run sorttrans (parse the $tmp_scan file)
# -sort Sc
# -cutoff 0.5
# Returns array of L<EMBL::Domain> 
# NB: might be just the probe. You need to check
sub sorttrans {
    my ($KEEP, %o) = @_;
    $o{-sort} ||= 'Sc';
    $o{-cutoff} ||= 0.5;

    my $tmp_prefix = $config->val('stamp', 'prefix') || 'stamp_trans';
    # File containing STAMP scan results
    my $tmp_scan = "${tmp_prefix}.scan";

    my $sorttrans = $config->val("stamp", "sorttrans") || 'sorttrans';
    my $params = "-i";
    my $com = join(' ', $sorttrans, $params,
                   "-f", $tmp_scan,
                   "-s", $o{-sort}, $o{-cutoff},
        );
#     print STDERR "$com\n";
    my $fh;
    unless (open($fh,"$com |")) {
        carp "Failed reading:\n$com\n";
        return;
    }

    # Read all doms
    my $io = new EMBL::DomainIO(-fh=>$fh);
    my @doms;
    push(@doms, $_) while $_ = $io->next_domain;

    # Remove any trailing counter (e.g. _34) from any domain IDs
    $_->{stampid} =~ s/_\d+$// for @doms;

    # Which domains are to be kept
    my @keep_doms = grep { defined($KEEP->{$_->stampid}) } @doms;

    return @keep_doms;

} # sorttrans


# Sorts objects given a pre-defined ordering.
# Takes:
# $objects - an arrayref of objects, in any order
# $accessor - the name of an accessor function to call on each object, like:
#     $_->$accessor()
# $ordering - an arrayref of strings in the desired order

sub reorder {
    my ($objects, $ordering, $accessor) = @_;

    # First put the objects into a dictionary, indexed by $func
    my %dict = map { $_->$accessor() => $_ } @$objects;
#     my %dict = map { $_->stampid() => $_ } @$objects;
    # Sorted array based on given ordering of keys
    my @sorted = map { $dict{$_} } @$ordering;
    return \@sorted;
}


# Returns (probe, disjoint)
# Disjoint==1 if not-yet-tried probe could not be found in %$current
sub next_probe {
    my ($all, $current, $tried) = @_;
    my $probe;

    # Get another probe from the current set, not yet tried
    ($probe) = grep { ! defined($tried->{$_}) } keys %$current;
    return ($probe, 0) if $probe;

    # Get another probe from anywhere (i.e. unconnected now), not yet tried
    ($probe) = grep { ! defined($tried->{$_}) } @$all;
    return ($probe, 1) if $probe;

    unless ($probe) {
        carp "Out of probes\n";
    }
    return;
} # next_probe


################################################################################
1;
