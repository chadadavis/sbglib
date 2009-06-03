#!/usr/bin/env perl

=head1 NAME

SBG::Eval - Evaluation routine to test accuracy of assembly of test complexes

=head1 SYNOPSIS

 use SBG::Eval;

=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::NetworkIO> , L<SBG::ComplexIO>

=cut

################################################################################

package SBG::Eval;
use SBG::Root -base;

# TODO DES don't need all of these
our @EXPORT = qw(parse_scopid get_descriptor mk_dom);

use warnings;

use SBG::Domain;

# TODO config.ini
# Needs to be in MySQL
my $scopdb = "/g/russell1/data/pdbrep/scop_1.73.dom";


################################################################################

# Returns PDBid,chainid,scop_classification
# TODO DES move to SCOP
sub parse_scopid {
    my $scopid = shift;
    unless ($scopid =~ /^(\d.{3})(.*?)\.(.*?)$/) {
        print STDERR "Couldn't parse SCOP ID: $scopid\n";
        return;
    }
    return ($1,$2,$3);
}



# Returns filepath,scopid,stamp_descriptor
# TODO DES move to SCOP
sub get_descriptor {
    my $scopid = shift;
    # Static opened file handle
    our $fh;
    unless ($fh) {
        unless (open $fh, $scopdb) {
            $logger->error("Cannot open: $scopdb ($!)");
            return;
        }
    }
    seek $fh, 0, 0;
    while (<$fh>) {
        next unless /^(\S+) ($scopid) { (.*?) }$/;
        return ($1, $2, $3);
    }
    return;
}

# TODO DES move to SCOP
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


