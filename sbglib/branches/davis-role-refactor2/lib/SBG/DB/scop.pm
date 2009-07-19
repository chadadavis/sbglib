#!/usr/bin/env perl

=head1 NAME

SBG::DB::scop - Database interface to cached centres-of-mass of PDB chains


=head1 SYNOPSIS

 use SBG::DB::scop;


=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::Domain>

=cut

################################################################################

package SBG::DB::scop;

use base qw/Exporter/;
our @EXPORT_OK = qw/scopdomain/;

use SBG::U::Log qw/log/;

use SBG::Domain;

# TODO Needs to be in a DB
# Maps e.g. 2hz1A.a.1.1.1-1 to { A 2 _ to A 124 _ }
#our $scopdb = "$ENV{HOME}/work/ca/benchmark/scop_1.73.dom.gz";
our $scopdb = "/g/russell2/davis/work/ca/benchmark/scop_1.73.dom.gz";


################################################################################
=head2 scopdomain

 Function: 
 Example : 
 Returns : 
 Args    : 

Given: 2hz1A.a.1.1.1-1, returns a L<SBG::Domain>

NB 'file' is bogus here, will be ignored

NB runs 'zgrep'

=cut
sub scopdomain {
    my ($longid) = @_;

    unless ($longid =~ /^(\d.{3})(.*?)\.(.*?)$/) {
        log()->error("Couldn't parse SCOP ID: $longid");
        return;
    }
    # NB $chainid may be more than one character
    my ($pdbid, $chainid, $sccs) = ($1, $2, $3);
    
    # Given: 2hz1A.a.1.1.1-1, this matches:
    # ("/data/pdb/2hz1.brk","2hz1A.a.1.1.1-1","A 2 _ to A 124 _")
    my $match = `zgrep $longid $scopdb`;
    unless ($match =~ /^(\S+) ($longid) { (.*?) }$/) {
        log()->error("SCOP ID not found: $longid");
        return;
    }
    my ($file, $descriptor) = ($1, $3);
    # NB 'file' is not verified here
    my %fields = (pdbid=>$pdbid, descriptor=>$descriptor, sccs=>$sccs);
    return new SBG::Domain(%fields);

} # scopdomain


################################################################################
1;
