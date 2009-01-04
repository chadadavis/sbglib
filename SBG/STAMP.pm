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
our @EXPORT = qw(do_stamp sorttrans stamp pickframe transform);
our @EXPORT_OK = qw(reorder)

use warnings;
use Carp;
use File::Temp qw(tempfile);
use IO::String;
use Data::Dumper;

use SBG::Transform;
use SBG::Domain;
use SBG::DomainIO;

################################################################################


# Converts an array of L<SBG::Domain>s to a PDB file
# returns Path to PDB file, if successful
sub transform {
    my ($doms, $pdbfile) = @_;
    (undef, $pdbfile) = tempfile unless $file;
    my (undef, $transfile) = tempfile;
    
    my $cmd = "transform -f ${transfile} -g -o $pdbfile";
    system($cmd);
    unless (-s $pdbfile) {
        carp "Failed:\n\t$cmd\n";
        return;
    }
    return $pdbfile;
} # transform



# Inputs are arrayref of L<SBG::Domain>s
# TODO caching, based on what? (PDB/PQS ID + descriptor)
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
        my ($probe, $in_disjoint) = _next_probe(\@dom_ids, \%current, \%tried);
        last unless $probe;
        $tried{$probe}=1;

        # Write probe domain to file
        my (undef, $tmp_probe) = tempfile();
        my $ioprobe = new SBG::DomainIO(-file=>">$tmp_probe");
        $ioprobe->write($domains{$probe});

        # Write other domains to single file
        my (undef, $tmp_doms) = tempfile();
        my $iodoms = new SBG::DomainIO(-file=>">$tmp_doms");
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
# NB STAMP uses lowercase chain IDs. Need to change IDs for pickframe?
# $key is a regular expression, case insensitive
sub pickframe {
    my ($key, $doms) = @_;
    # Find the domain with the given stampid
    my ($ref) = grep { $_->stampid =~ /$key/i } @$doms;
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


# Returns IDs of the domains to keep, based on Sc cutoff
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
# Returns array of L<SBG::Domain> 
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
    my $io = new SBG::DomainIO(-fh=>$fh);
    my @doms;
    push(@doms, $_) while $_ = $io->next_domain;

    # Remove any trailing counter (e.g. _34) from any domain IDs
    $_->{stampid} =~ s/_\d+$// for @doms;

    # Which domains are to be kept
    my @keep_doms = grep { defined($KEEP->{$_->stampid}) } @doms;

    return @keep_doms;

} # sorttrans


# The Perl sort() is fine for sorting things alphabeticall/numerically.
#   This is for sorting objects in a pre-defined order, based on some attribute
# Sorts objects, given a pre-defined ordering.
# Takes:
# $objects - an arrayref of objects, in any order
# $accessor - the name of an accessor function to call on each object, like:
#     $_->$accessor()
# Otherwise, standard Perl stringification is used on the objects, i.e. "$obj"
# $ordering - an arrayref of keys (as strings) in the desired order
#   If no ordering given, sorts lexically
# E.g.: 
sub reorder {
    my ($objects, $ordering, $accessor) = @_;

    # First put the objects into a dictionary, indexed by $func
    my %dict;
    if ($accessor) {
        %dict = map { $_->$accessor() => $_ } @$objects;
    } else {
        %dict = map { $_ => $_ } @$objects;
    }

    # Sort lexically by default
    $ordering ||= [ sort keys %dict ];
    # Sorted array based on given ordering of keys
    my @sorted = map { $dict{$_} } @$ordering;
    return \@sorted;
}


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

    unless ($probe) {
        carp "Out of probes\n";
    }
    return;
} # _next_probe


################################################################################
1;

__END__


