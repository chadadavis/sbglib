#!/usr/bin/env perl

=head1 NAME

SBG::DomainIO::cofm - IO for L<SBG::Domain> objects, in cofm crosshair format

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::Domain> , L<SBG::IOI>

PDB file format, Version 3.20 (Sept 15, 2008)
http://www.wwpdb.org/documentation/format32/v3.2.html

=cut

################################################################################

package SBG::DomainIO::cofm;
use Moose;

with 'SBG::IOI';

use Log::Any qw/$log/;

use SBG::U::List qw/flatten/;


=head2 objtype

The sub-objtype to use for any dynamically created objects. Should implement
L<SBG::DomainI> role. Default "L<SBG::Domain>" .

=cut
# has '+objtype' => (
#     default => 'SBG::Domain',
#     );


sub BUILD {
    my ($self) = @_;
    $self->objtype('SBG::Domain') unless $self->objtype;
}




################################################################################
=head2 write

 Function: 
 Example : 
 Returns : 
 Args    : 

Depends on the B<transform> program from the STAMP suite

http://www.compbio.dundee.ac.uk/Software/Stamp/stamp.html

=cut
sub write {
    my ($self, @doms) = @_;
    return unless @doms;
    @doms = flatten(@doms);

    my $fh = $self->fh;

    for (my $i = 0; $i < @doms; $i++) {
        my $dom = $doms[$i];
        my $domain = $i+1;
        my $chain = chr(ord('A') + $i);

        $log->debug("Domain $domain : ", $dom->id, " chain $chain");

        printf $fh 
            "REMARK Domain %2d Id %4s N = %5d Rg = %7.3f Rmax = %7.3f " . 
            "Ro = %8.3f  %8.3f  %8.3f\n",
            $domain, $dom->id, 0, $dom->radius, 0, 
            $dom->coords->slice('0:2,0')->list;

        for (my $j = 0; $j < 7; $j++) {
            printf $fh
                "%-6s" .   # Record
                "%5d"  .   # Atom serial num
                " "    .
                "%-4s" .   # Atom name
                "%1s"  .   # Alt location
                "%3s"  .   # Res name
                " "    .
                "%1s"  .   # Chain
                "%4d"  .   # Res. seq. number
                "%1s"  .   # Res. insert. code
                "   "  .
                "%8.3f%8.3f%8.3f" . # X,Y,Z
                "%6.2f".   # Occupancy
                "%6.2f".   # Temperature factor
                "\n",
                'ATOM', $j, 'CA', ' ', 'ALA', $chain, $j, ' ',
                $dom->coords->slice("0:2,$j")->list, 
                1, 10;
        }
    }

    return $self;
} # write


################################################################################
=head2 read

 Function: 
 Example : 
 Returns : 
 Args    : 

TODO needs to be taken from Run::cofm::_run and then call this from there


=cut
sub read {
    my ($self) = @_;

    my $coords;

    # What type of Domain to create:
    my $objtype = $self->objtype;
    # Also note the file that was read from
    my $dom = $objtype->new(coords=>$coords, file=>$self->file());
    return $dom;

}


################################################################################
__PACKAGE__->meta->make_immutable;
no Moose;
1;
