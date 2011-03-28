#!/usr/bin/env perl

=head1 NAME

SBG::DomainIO::cofm - I/O for STAMP's cofm (center of mass) format

=head1 SYNOPSIS


=head1 DESCRIPTION

Note that the 'REMARK' line that immediately preceeds a block of 'ATOM' lines is 
space-separated, whereas the 'ATOM' records are a column-based format.
See PDB format spec below.



=head1 SEE ALSO

L<SBG::Domain> , L<SBG::IOI> , L<SBG::STAMP>

STAMP
PDB file format, Version 3.20 (Sept 15, 2008)
http://www.wwpdb.org/documentation/format32/v3.2.html

=cut



package SBG::DomainIO::cofm;

use Moose;
with 'SBG::IOI';

use Log::Any qw/$log/;

use SBG::U::List qw/flatten/;


=head2 objtype

Input data will create new objects of this type

=cut
has '+objtype' => (
     default => 'SBG::Domain::Sphere',
     );


=head2 homogenous

Whether to use homogenous coordinates, whereby each 3D point is extended to 4D 
with an additional 1. 
E.g. the point 

 ( 33.434, -23.003, 129.332 ) 

becomes the 4D point: 

 ( 33.434, -23.003, 129.332, 1).

Default: 1 (enabled)

This makes http://en.wikipedia.org/wiki/Affine_transformation easier

=cut
has 'homogenous' => (
    is => 'rw',
    isa => 'Bool',
    default => 1,
    );


sub BUILD {
    my ($self) = @_;
    $self->objtype('SBG::Domain') unless $self->objtype;
}


=head2 write

 Function: 
 Example : 
 Returns : 
 Args    : L<SBG::Domain::Sphere> object(s)

If multiple domains are given, they are appended in the same file.

TODO BUG currently does not retain the original chain ID, as a domain may span
multiple chains. Would be preferable to retain the chain ID for sub-chain doamains
and simply create new chain IDs for those muliple-chain domains.

NB This does not print the header information provided by 'cofm -v' verbose mode
It only prints the 'REMARK' header line for each domain.

Each atom is represented as Alpha-Carbon of Alanine
                
=cut
sub write {
    my ($self, @doms) = @_;
    return unless @doms;
    @doms = flatten(@doms);

    my $fh = $self->fh;

    for (my $i = 0; $i < @doms; $i++) {
        my $dom = $doms[$i];
        unless ($dom->isa('SBG::Domain::Sphere')) {
            warn "__PACKAGE__ wants 'SBG::Domain::Sphere', not " . ref($dom);
            next;
        } 
        my $domain = $i+1;
        my $chain = chr(ord('A') + $i);

        $log->debug("Domain $domain : ", $dom->id, " chain $chain");

        # This is a space-separated header format
        printf $fh 
            "REMARK Domain %2d Id %4s N = %5d Rg = %7.3f Rmax = %7.3f " . 
            "Ro = %8.3f  %8.3f  %8.3f\n",
            $domain, $dom->id, 0, $dom->radius, 0, 
            $dom->coords->slice('0:2,0')->list;

        # This is a column-based format (defined by the PDB specification)
        for (my $j = 0; $j < 7; $j++) {
            # Vary the temparature, to be able to visualize relative orientation
            # But only display every second one, to be able to identify +x vs -x
            my $temp = ($j % 2) * 4 * $j;
            
            printf $fh
                '%-6s' .   # Record
                '%5d'  .   # Atom serial num
                ' '    .
                '%-4s' .   # Atom name (default 'CA')
                '%1s'  .   # Alt location
                '%3s'  .   # Res name (default 'ALA')
                ' '    .
                '%1s'  .   # Chain
                '%4d'  .   # Residue sequence number
                '%1s'  .   # Residue insertion code
                '   '  .
                '%8.3f'.   # X coordinate
                '%8.3f'.   # Y coordinate
                '%8.3f' .  # Z coordinate
                '%6.2f'.   # B-Occupancy
                '%6.2f'.   # Temperature factor
                "\n",
                'ATOM', $j, 'CA', ' ', 'ALA', $chain, $j, ' ',
                $dom->coords->slice("0:2,$j")->list, 1.0, $temp;
        }
    }

    return $self;
} # write


=head2 read

 Function: 
 Example : 
 Returns : 
 Args    : 


When cofm is run with -v (verbose) option, file name and lengths are also given:

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


With or without the -v option, each domain will have one 'REMARK Domain' line
This preceedes the block of ATOM records for each domain, e.g.:

 REMARK Domain 1 Id 1li4a N = 860 Rg = 34.441 Rmax = 58.412 Ro = 44.760 0.000 85.323


=cut
sub read {
    my ($self) = @_;
    my $fh = $self->fh;
    return unless $fh;

    # The domains are numbered (from 1)    
    my $bydom = {};
    # Another index, by chain ID (from 'A')
    my $bychain = {};
    
    # First parse through all the ATOM records
    
    
    # All header lines come first, if any
    # These have to be matched to one another by the domain counter (Int, from 1)    

    my $last;        
    while (my $line = <$fh>) {
        if ($line =~ /^Domain\s+(\d+)\s+(\S+)/i) {
            $last = $1;
            $doms->[$last] = {};
            $doms->[$last]->{'file'} = $2;
        } elsif ($line =~ /^\s*\S+\s+(.).*?(\d+) CAs in total/) {
            $doms->[$last]->{
            $res{nres} = $1;
        } elsif ($line =~ /^REMARK Domain/) {
            my @a = quotewords('\s+', 0, $line);
            # Extract coords for radius-of-gyration and xyz of centre-of-mass
            $res{Rg} = $a[10];
            $res{Rmax} = $a[13];
            ($res{Cx}, $res{Cy}, $res{Cz}) = ($a[16], $a[17], $a[18]);
        } elsif ($line =~ /^ATOM/) {
            # We dont' parse ATOM records, SBG::DomainIO::pdb does that
        }
          
    } # while


    unless (%res && $res{nres} > 0) { 
        seek $cofmfh, 0, 0;
        $log->error("Failed to parse:", <$cofmfh>);
        return;
    }

    # keys: (Cx, Cy,Cz, Rg, Rmax, description, file, descriptor)
    return \%res;


    # ATOM lines
    if ($self->homogenous) { 'add a 1 to the PDL vector, append it to matrix' }
    
    # Alternate approach. PDL might be faster than Perl here.
    # Try parsing by restricting to Chain, once it's known.
    # On the other hand, we have to parse it anyway to figure out the chain.
    
    # Idea:
    # Suck up the whole thing into a PDL, and use slice to represent substructures?
    # Can use binary search to find the boundaries of models and chains
    # Can then also map residues index to residue ID and vice versa
    # Also index atom types? (make these indexes optional, though, slow to build)
    # And lazy build them (then only created when used).
    # Just do CA by default, and do binary search to find model / chain boundaries    

    # What type of Domain to create:
    my $objtype = $self->objtype;
    # Also note the file that was read from
    my $dom = $objtype->new(coords=>$coords, file=>$self->file());
    return $dom;
    
    
    # Append 1 for homogenous coordinates
    # TODO needs to be contained in Domain::Sphere hook
    my $center = pdl($fields->{Cx}, $fields->{Cy}, $fields->{Cz}, 1);
    # Copy construct, manually
    # TODO poor design for the case when additional attributes are added
    $sphere = SBG::Domain::Sphere->new(pdbid=>$dom->pdbid,
                                       descriptor=>$dom->descriptor,
                                       file=>$fields->{file},
                                       center=>$center,
                                       radius=>$fields->{Rg},
                                       length=>$fields->{nres},
                                       transformation=>$dom->transformation->clone,
        );
    
}



=head2 _read_header

 Function: 
 Example : 
 Returns : 
 Args    : 

This input exists when cofm is run with the -v (verbose) option

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


=cut
sub _read_header {
    my ($self) = @_;
    my $fh = $self->fh;
    return unless $fh;
    
    my $doms = {};
    # Each dom has a chain too
    # Reading ATOM records, just append to the PDL of the dom, homog coords
    
    # Header lines come first, all headers for all domains before any data
    # Then the coordinate lines come, 
    # These have to be matched to one another by the domain counter (Int)    
    

__PACKAGE__->meta->make_immutable;
no Moose;
1;
