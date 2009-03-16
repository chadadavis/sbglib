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

use Carp;
use IO::String;
use PDL::Lite;
use PDL::Matrix;
use Text::ParseWords;

use SBG::Types qw/$re_chain_id/;
use SBG::DB::cofm;
use SBG::Config qw/val/;
use SBG::Domain;
use SBG::DomainIO;


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
        carp "Cannot get centre-of-mass for ${pdbid} \{ ${descriptor} \}";
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

All of the ATOM lines are saved, as new-line separated text in the 'description'

BUG: Insertion code ignored by cofm?
No, just not always there ...:
        from B  100   to B  131 A  33 CAs =>   33 CAs in total

=cut
sub _run {
    my ($pdbid, $descriptor) = @_;
    return unless $pdbid && $descriptor;
    # Get dom into a stamp-formatted file
    my $path = _spitdom($pdbid, $descriptor) or return;

    # NB the -v option is necessary if you want the filename of the PDB file
    my $cofm = val(qw/cofm executable/) || 'cofm';
    my $cmd = "$cofm -f $path -v |";
    open my $cofmfh, $cmd;
    unless ($cofmfh) {
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
            # TODO BUG What about insertion code here?
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
        } elsif (/^ATOM/) {
            $res{description} .= $_;
        }
        
    }

    unless (%res) {
        return;
    }
    
    # Check that $descriptor eq $found_descriptor 
    carp "Descriptors unequal:$descriptor:$res{descriptor}:" unless
        $descriptor eq $res{descriptor};

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
    my $path = $io->file;
    $io->write($dom);
    $io->close;
    unless (-s $path) {
        carp "Failed to write Domain to tempfile: $path";
        return;
    }
    return $path;
}


################################################################################
=head2 _atom2pdl

 Function: 
 Example : 
 Returns : 
 Args    : 

Parses ATOM lines and converts to nx3-dimensional L<PDL::Matrix>

Any lines not beginning wth ATOM are skipped.

E.g.:

 ATOM      0  CA  ALA Z   0      80.861  12.451 122.080  1.00 10.00
 ATOM      1  CA  ALA Z   1      85.861  12.451 122.080  1.00 10.00
 ATOM      1  CA  ALA Z   1      75.861  12.451 122.080  1.00 10.00
 ATOM      2  CA  ALA Z   2      80.861  17.451 122.080  1.00 10.00
 ATOM      2  CA  ALA Z   2      80.861   7.451 122.080  1.00 10.00
 ATOM      3  CA  ALA Z   3      80.861  12.451 127.080  1.00 10.00
 ATOM      3  CA  ALA Z   3      80.861  12.451 117.080  1.00 10.00

31 - 38        Real(8.3)     x            Orthogonal coordinates for X in Angstroms.
39 - 46        Real(8.3)     y            Orthogonal coordinates for Y in Angstroms.
47 - 54        Real(8.3)     z            Orthogonal coordinates for Z in Angstroms.

TODO DES belongs in a more general module. At least Domain::CofM

=cut
sub _atom2pdl {
    my ($atomstr) = @_;
    my $io = new IO::String($atomstr);
    my @mat;
    for (my $i = 0; <$io>; $i++) {
        next unless /^ATOM/;
        my $str = $_;
        # Columns 31,39,47 store the 8-char coords (not necessarily separated)
        # substr() is 0-based
        my @xyz = map { substr($str,$_,8) } (30,38,46);
        # Append array with an arrayref of X,Y,Z fields
        push @mat, [ @xyz ];
    }
    return mpdl @mat;
}


################################################################################
1;
