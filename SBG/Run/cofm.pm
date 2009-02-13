#!/usr/bin/env perl

=head1 NAME

SBG::Run::cofm - Wrapper for running B<cofm> (centre-of-mass), with DB caching.


=head1 SYNOPSIS

 use SBG::Run::cofm;
 my ($x,$y,z,$rg,$max) = 
    SBG::Run::cofm::run('2nn6','A 13 _ to A 331 _');


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

use Carp;
use SBG::Types qw/$re_chain_id/;
use SBG::DB::cofm;
use SBG::Config qw/val/;
use SBG::Domain;
use SBG::DomainIO;

use Text::ParseWords;


################################################################################
=head2 cofm

 Function: 
 Example : 
 Returns : HashRef with keys: Cx, Cy,Cz, Rg, Rmax, file, descriptor
 Args    : 

If the Domain is an entire chain, the database cache is queried first. Otherwise
cofm is run locally, if available. 

B<cofm> must be in your PATH, or defined in a B<config.ini> file

The DB cache stores uppercase PDB IDs. The B<cofm> program will accept any case.

=cut
sub cofm {
    my ($pdbid, $descriptor) = @_;
    return unless $pdbid && $descriptor;
    my ($chainid) = $descriptor =~ /^\s*CHAIN\s+($re_chain_id)\s*$/;

    my $res;
    # If descriptor contains just one full chain, try the cache first;
    $res = SBG::DB::cofm::query($pdbid, $chainid) if $chainid;

    # Couldn't get from DB, try running computation locally, on descriptor
    $res = run($pdbid, $descriptor) unless defined($res);

    unless ($res) {
        carp "Cannot get centre-of-mass for ${pdbid} ${descriptor}";
        return;
    }

    # keys: (Cx, Cy,Cz, Rg, Rmax, file, descriptor)
    return $res;

} # cofm


################################################################################
=head2 run

 Function: Computes centre-of-mass and radius of gyration of STAMP domain
 Example : 
 Returns : HashRef with keys: Cx, Cy,Cz, Rg, Rmax, file, descriptor
 Args    : L<SBG::Domain>

Runs external B<cofm> appliation. Must be in your environment's B<$PATH>

'descriptor' and 'pdbid' must be defined 

E.g. 

 Domain   1 /g/russell3/pqs/1li4.mmol 1li4A
        chain A 430 CAs =>  430 CAs in total

 Domain   1 /g/russell3/pqs/1li4.mmol 1li4a
        chain A 430 CAs  chain B 430 CAs =>  860 CAs in total
or: 

 Domain   1 /g/russell3/pqs/1li4.mmol 1li4A-single
        from A    3   to A  189   187 CAs =>  187 CAs in total

or:
 Domain   1 /g/russell3/pqs/1li4.mmol 1li4A-double
        from A    3   to A  189   187 CAs  from A  353   to A  432    80 CAs =>  267 CAs in total

And then, a few lines later:

 REMARK Domain 1 Id 1li4a N = 860 Rg = 34.441 Rmax = 58.412 Ro = 44.760 0.000 85.323


=cut
sub run {
    my ($pdbid, $descriptor) = @_;
    return unless $pdbid && $descriptor;
    
    my $dom = new SBG::Domain(pdbid=>$pdbid,descriptor=>$descriptor);
    my $io = new SBG::DomainIO(tempfile=>1);
    my $path = $io->file;
    $io->write($dom);
    $io->close;
    unless (-s $path) {
        carp "Failed to write Domain to tempfile: $path";
        return;
    }

    # NB the -v option is necessary if you want the filename of the PDB file
    my $cofm = val(qw/cofm executable/) || 'cofm';
    my $cmd = "$cofm -f $path -v |";

    my $cofmfh;
    unless (open $cofmfh, $cmd) {
        carp "Failed:\n\t$cmd\n\t$!";
        return;
    }

    my %res;
    while (<$cofmfh>) {
        if (/^Domain\s+\S+\s+(\S+)/i) {
            $res{file} = $1;
        } elsif (my @chs = /chain\s+($re_chain_id)/ig) {
            # Maybe multiple chains here
            my @tchs = map { "CHAIN $_" } @chs;
            $res{descriptor} = join(' ', @tchs);
        } elsif (my @descrs = /from\s+(\S+)\s+(\S+)\s+to\s+\1\s+(\S+)/ig) {
            # Maybe multiple segments here. Capture all and re-format
            my @groupdescrs;
            while (@descrs) {
                # Region = chain, start, end
                my @reg = (shift(@descrs), shift(@descrs), shift(@descrs));
                push @groupdescrs, \@reg if @reg == 3;
            }
            # Convert each array triple into the STAMP descriptor string
            my @regions = 
                map { my ($c,$s,$e) = @$_; "$c $s _ to $c $e _" } @groupdescrs;
            # Concat all descriptor strings
            $res{descriptor} = join(' ', @regions);
        } elsif (/^REMARK Domain/) {
            my @a = quotewords('\s+', 0, $_);
            # Extract coords for radius-of-gyration and xyz of centre-of-mass
            $res{Rg} = $a[10];
            $res{Rmax} = $a[13];
            ($res{Cx}, $res{Cy}, $res{Cz}) = ($a[16], $a[17], $a[18]);
        }
    }

    # Check that $descriptor eq $found_descriptor 
    carp "Descriptors unequal:$descriptor:$res{descriptor}:" unless
        $descriptor eq $res{descriptor};

    # keys: (Cx, Cy,Cz, Rg, Rmax, file, descriptor)
    return \%res;

} # run


################################################################################
1;
