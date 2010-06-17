#!/usr/bin/env perl

=head1 NAME

SBG::Run::cofm - Wrapper for running B<cofm> (centre-of-mass)


=head1 SYNOPSIS

 use SBG::Run::cofm qw/cofm/;

 my $dom = SBG::DomainI->new(pdbid=>'2nn6', descriptor=>'A 13 _ to A 331 _');
 my $centroid = cofm($dom);

 my $dom = SBG::DomainI->new(pdbid=>'2nn6', descriptor=>'A 13 _ to A 331 _');

 $hashref = cofm('2nn6','A 13 _ to A 331 _');
 $hashref = cofm('2nn6','CHAIN A CHAIN B');


=head1 DESCRIPTION

Fetches center of mass, radius of gyration and maximum radius of the centre of
mass.

=head1 SEE ALSO

B<cofm> is a program in the STAMP suite.

L<SBG::U::DB::cofm> , L<SBG::Domain::CofM>

=cut



package SBG::Run::cofm;
use base qw/Exporter/;
our @EXPORT_OK = qw/cofm/;

use Text::ParseWords qw/quotewords/;
use PDL::Lite;
use PDL::Core qw/pdl/;
use Log::Any qw/$log/;
use Digest::MD5 qw/md5_base64/;

use SBG::Domain::Sphere;
use SBG::DomainIO::stamp;
use SBG::U::Cache qw/cache_get cache_set/;

# TODO DES OO
# cofm binary (should be in PATH)
our $cofm = 'cofm';

our $cachename = 'sbgcofm';



=head2 cofm

 Function: 
 Example : 
 Returns : a new L<SBG::Domain::Sphere>
 Args    : L<SBG::DomainI>

Original Domain is not modified

B<cofm> must be in your PATH, or defined in a B<config.ini> file

NB if the input L<SBG::DomainI> has a B<transformation>, this is not saved in
the newly created L<SBG::Domain::Sphere>

TODO option to use Rg or Rmax as the resulting radius

=cut
sub cofm {
    my ($dom, %ops) = @_;
    our %cofm_cache;
    # Caching on by default
    my $cache = 1 unless defined $ops{'cache'};
    my $key = _hash($dom);
    my $sphere;
    $sphere = cache_get($cachename, $key) if $cache;
    if (defined $sphere) {
        # [] is the marker for a negative cache entry
        return if ref($sphere) eq 'ARRAY';
        return $sphere;
    }

    # Cache miss, run external program
    my $fields = _run($dom);
    unless ($fields) {
        # cofm failed, set negative cache entry
        cache_set($cachename, $key, []) if $cache;
        return;
    }


    # Append 1 for homogenous coordinates
    # TODO needs to be contained in Domain::Sphere hook
    my $center = pdl($fields->{Cx}, $fields->{Cy}, $fields->{Cz}, 1);
    # Copy construct, manually
    $sphere = SBG::Domain::Sphere->new(pdbid=>$dom->pdbid,
                                       descriptor=>$dom->descriptor,
                                       file=>$fields->{file},
                                       center=>$center,
                                       radius=>$fields->{Rg},
                                       length=>$fields->{nres},
                                       transformation=>$dom->transformation->clone,
        );
    cache_set($cachename, $key, $sphere) if $cache;

    return $sphere;

} # cofm


# Hash a DomainI, including any transformation coords
sub _hash {
    my ($dom) = @_;
    my $domstr = "$dom";
    my $trans = $dom->transformation;
    my $transstr = md5_base64 "$trans";
    $domstr .= '(' . $transstr . ')' if $transstr;
    return $domstr;
}



=head2 _run

 Function: Computes centre-of-mass and radius of gyration of STAMP domain
 Example : 
 Returns : HashRef with keys: Cx, Cy,Cz, Rg, Rmax, file, 
 Args    : L<SBG::DomainI>

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
    my ($dom) = @_;

    # Get dom into a stamp-formatted file
    my $io = SBG::DomainIO::stamp->new(tempfile=>1);
    $io->write($dom);
    my $path = $io->file;
    $io->close;

    # NB the -v option is necessary if you want the filename of the PDB file
    our $cofm;
    my $cmd = "$cofm -f $path -v |";
    my $cofmfh;
    unless (open $cofmfh, $cmd) {
        $log->error("Failed:\n\t$cmd\n\t$!");
        return;
    }

    my %res;
    while (my $line = <$cofmfh>) {

        if ($line =~ /^Domain\s+\S+\s+(\S+)/i) {
            $res{file} = $1;
        } elsif ($line =~ / (\d+) CAs in total/) {
            $res{nres} = $1;
        } elsif ($line =~ /^REMARK Domain/) {
            my @a = quotewords('\s+', 0, $line);
            # Extract coords for radius-of-gyration and xyz of centre-of-mass
            $res{Rg} = $a[10];
            $res{Rmax} = $a[13];
            ($res{Cx}, $res{Cy}, $res{Cz}) = ($a[16], $a[17], $a[18]);
        }
    } # while

    unless (%res && $res{nres} > 0) { 
    	seek $cofmfh, 0, "SEEK_SET";
    	$log->error("Failed to parse:", <$cofmfh>);
    	return;
    }

    # keys: (Cx, Cy,Cz, Rg, Rmax, description, file, descriptor)
    return \%res;

} # _run


1;
