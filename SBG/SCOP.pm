#!/usr/bin/env perl

=head1 NAME

SBG::SCOP - Utilities for working with SCOP, a functional interface

=head1 SYNOPSIS

 use SBG::SCOP;

=head1 DESCRIPTION


Also fetches radius of gyration of the centre of mass.

=head1 SEE ALSO

L<SBG::DB>

=cut

################################################################################

package SBG::SCOP;
use SBG::Root -base;

our @EXPORT_OK = qw(pdb2scop lca equiv parse_scopid get_descriptor);

use warnings;

use SBG::DB;
use List::MoreUtils qw(each_array each_arrayref all);


################################################################################
=head2 pdb2scop

 Title   : pdb2scop
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut
sub pdb2scop {
    my (%o) = @_;
    SBG::Root::_undash %o;
    $o{pdb} or return;

#     my $dbh = dbconnect(-db=>$db) or return undef;
    # Static handle, prepare it only once
#     our $pdb2scop_sth;


} # pdb2scop

# Lowest common ancestor of multiple SCOP codes
# Returns longest common prefix of multiple SCOP strings.
# E.g. 
# qw(a.3.2.2 a.3.4.5 a.3.4.1) => a.3
# qw(a.3.2.2-1 a.3.2.2-1) => a.3.2.2-1
# qw(a.3.2.2-1 a.3.2.2-2) => a.3.2.2
sub lca {
    my @classes = map { [ split(/[.-]/) ] } @_;
    my @lca;
    my $ea = each_arrayref(@classes);
    while (my @a = $ea->()) {
        my $x = $a[0];
        last unless all { $x eq $_ } @a;
        push @lca, $x;
    }
    return join('-', join('.', @lca[0..3]), @lca[4..$#lca]);
}

# Returns true if $a and $b are the same SCOP classification, at given depth
# depth=0 => (default) true when $a eq $b
# depth=1 => true for a.1.2.3 and a.2.3.4 (lca is 'a')
# ...
# depth=4 => true for a.1.2.3-1 and a.1.2.3-2 (lca is a.1.2.3)
# depth=5 => same as depth=0 ($a eq $b eq lca($a,$b))
# NB equiv("a.1.2", "a.1.2", 4) will be false: original labels only length 3
sub equiv {
    my ($a, $b, $depth) = @_;
    return $a eq $b unless $depth;
    my $lca = lca($a,$b);
    my @s = split /[.-]/, $lca;
    return defined $s[$depth-1];
}



# Returns PDBid,chainid,scop_classification
sub parse_scopid {
    my $scopid = shift;
    unless ($scopid =~ /^(\d.{3})(.*?)\.(.*?)$/) {
        print STDERR "Couldn't parse SCOP ID: $scopid\n";
        return;
    }
    return ($1,$2,$3);
}



# Returns filepath,scopid,stamp_descriptor
sub get_descriptor {
    my $scopid = shift;
    # Static opened file handle
    our $fh;
    $fh or open $fh, $scopdb;
    seek $fh, 0, 0;
    while (<$fh>) {
        next unless /^(\S+) ($scopid) { (.*?) }$/;
        return ($1, $2, $3);
    }
    return;
}


sub mk_dom {
    my ($str) = @_;
    my ($pdbid, $chainid, $scopid) = parse_scopid($str);
    my ($file, undef, $descriptor) = get_descriptor($str);
    my $dom = new SBG::Domain(
        -pdbid=>$pdbid, -chainid=>$chainid, -scopid=>$scopid,
        -file=>$file, -descriptor=>$descriptor);
}


################################################################################
1;

__END__


