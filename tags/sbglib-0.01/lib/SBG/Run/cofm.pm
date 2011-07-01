#!/usr/bin/env perl

=head1 NAME

SBG::Run::cofm - Wrapper for running B<cofm> (centre-of-mass), with DB caching.


=head1 SYNOPSIS

 use SBG::Run::cofm;
 $hashref = SBG::Run::cofm::run('2nn6','A 13 _ to A 331 _');
 $hashref = SBG::Run::cofm::run('2nn6','CHAIN A CHAIN B');


=head1 DESCRIPTION

Looks up cached centre-of-mass in database, if available. This is only the case
for full chains. Otherwise, cofm is executed anew.

Also fetches radius of gyration and maximum radius of the centre of mass.

=head1 SEE ALSO

L<SBG::DB::cofm> , L<SBG::Domain::CofM>

=cut

################################################################################

package SBG::Run::cofm;
use base qw/Exporter/;
our @EXPORT_OK = qw/cofm/;

use Text::ParseWords;

use SBG::Types qw/$re_chain $re_chain_id $re_ic $re_pos/;
use SBG::DB::cofm;
use SBG::Config qw/config/;
use SBG::Domain;
use SBG::DomainIO;
use SBG::Log;

################################################################################
=head2 cofm

 Function: 
 Example : 
 Returns : HashRef with keys: Cx, Cy,Cz, Rg, Rmax, file, descriptor
 Args    : 

If the Domain is one entire chain, the database cache is queried
first. Otherwise cofm is run locally, if available.

B<cofm> must be in your PATH, or defined in a B<config.ini> file

The DB cache stores uppercase PDB IDs. The B<cofm> program will accept any case.

=cut
sub cofm {
    my ($pdbid, $descriptor) = @_;
    return unless $pdbid && $descriptor;
    my $dom = new SBG::Domain(pdbid=>$pdbid, descriptor=>$descriptor);

    my $res;
    # If descriptor contains just one full chain, try the cache first;
    my $chainid = $dom->wholechain();
    $res = SBG::DB::cofm::query($pdbid, $chainid) if $chainid;

    # Couldn't get from DB, try running computation locally, on descriptor
    $res = _run($pdbid, $descriptor) unless defined($res);

    unless ($res) {
        $logger->warn(
            "Cannot get centre-of-mass for ${pdbid} \{ ${descriptor} \}");
        return;
    }

    # keys: (Cx, Cy, Cz, Rg, Rmax, description, file, descriptor)
    return $res;

} # cofm


################################################################################
=head2 _run

 Function: Computes centre-of-mass and radius of gyration of STAMP domain
 Example : 
 Returns : HashRef with keys: Cx, Cy,Cz, Rg, Rmax, description, file, descriptor
 Args    : L<SBG::Domain>

Runs external B<cofm> appliation. Must be in your environment's B<$PATH>

'descriptor' and 'pdbid' must be defined 

Examples:
Single chain:

 Domain   1 /g/russell3/pqs/1li4.mmol 1li4A
        chain A 430 CAs =>  430 CAs in total

Multiple chains:
 Domain   1 /g/russell3/pqs/1li4.mmol 1li4a
        chain A 430 CAs  chain B 430 CAs =>  860 CAs in total

Segment:
 Domain   1 /g/russell3/pqs/1li4.mmol 1li4A-single
        from A    3   to A  189   187 CAs =>  187 CAs in total

Multiple segments:
 Domain   1 /g/russell3/pqs/1li4.mmol 1li4A-double
        from A    3   to A  189   187 CAs  from A  353   to A  432    80 CAs =>  267 CAs in total

With insertion codes:
Domain   1 /usr/local/data/pdb/pdb2frq.ent.gz 2frqB
        from B  100   to B  131 A  33 CAs =>   33 CAs in total

And then, a few lines later (the header line with the centre of mass):

 REMARK Domain 1 Id 1li4a N = 860 Rg = 34.441 Rmax = 58.412 Ro = 44.760 0.000 85.323

All of the ATOM lines are saved, as new-line separated text in the 'description'


=cut
sub _run {
    my ($pdbid, $descriptor) = @_;
    return unless $pdbid && $descriptor;
    # Get dom into a stamp-formatted file
    my $io = _spitdom($pdbid, $descriptor) or return;
    my $path = $io->file;

    # NB the -v option is necessary if you want the filename of the PDB file
    my $cofm = config()->val(qw/cofm executable/) || 'cofm';
    my $cmd = "$cofm -f $path -v |";
    my $cofmfh;
    unless (open $cofmfh, $cmd) {
        $logger->error("Failed:\n\t$cmd\n\t$!");
        return;
    }


    my %res;
    while (<$cofmfh>) {
        if (/^Domain\s+\S+\s+(\S+)/i) {
            $res{file} = $1;
        } elsif (/^REMARK Domain/) {
            my @a = quotewords('\s+', 0, $_);
            # Extract coords for radius-of-gyration and xyz of centre-of-mass
            $res{Rg} = $a[10];
            $res{Rmax} = $a[13];
            ($res{Cx}, $res{Cy}, $res{Cz}) = ($a[16], $a[17], $a[18]);

# Don't need to parse this, easily computable
#         } elsif (/^ATOM/) {
#             $res{description} .= $_;

        }
    }

    unless (%res) {
        return;
    }
    
    # keys: (Cx, Cy,Cz, Rg, Rmax, description, file, descriptor)
    return \%res;

} # run



################################################################################
=head2 _spitdom

 Function: 
 Example : 
 Returns : 
 Args    : 

Dumps domain in STAMP format to file.

=cut
sub _spitdom {
    my ($pdbid, $descriptor) = @_;
    my $dom = new SBG::Domain(pdbid=>$pdbid,descriptor=>$descriptor);
    my $io = new SBG::DomainIO(tempfile=>1);
    $io->write($dom);
    $io->close;
    my $path = $io->file;
    unless (-s $path) {
        $logger->error("Failed to write Domain to: $path");
        return;
    }
    return $io;
}



################################################################################
1;
