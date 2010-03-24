#!/usr/bin/env perl

=head1 NAME

SBG::DomainIO::pdbcofm - IO for L<SBG::Domain> objects, in PDB format, with CofM

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::Domain> , L<SBG::IOI> , L<SBG::STAMP>

PDB file format, Version 3.20 (Sept 15, 2008)
http://www.wwpdb.org/documentation/format32/v3.2.html

=cut

################################################################################

package SBG::DomainIO::pdbcofm;
use Moose;

with 'SBG::IOI';

use Carp;

use SBG::U::List qw/flatten/;

# Combine these
use SBG::DomainIO::pdb;
use SBG::DomainIO::cofm;



################################################################################
=head2 write

 Function: 
 Example : 
 Returns : 
 Args    : 

Resulting chains will have the same identifiers. I.e a structure will be labeled
as chain A, as will it's crosshairs.


=cut
sub write {
    my ($self, @doms) = @_;
    return unless @doms;
    @doms = flatten(@doms);

    # Do PDB first, as file will be overwritten
    my $pdbio = new SBG::DomainIO::pdb(file=>$self->file);
    $pdbio->write(@doms);

    # Append to file
    my $cofmio = new SBG::DomainIO::cofm(file=>">>" . $self->file);
    $cofmio->write(@doms);

    return $self;
} # write


################################################################################
=head2 read

 Function: 
 Example : 
 Returns : 
 Args    : 

NB This does not set the L<pdbid> or L<descriptor> fields of the L<SBG::DomainI>
object, as these cannot always be determined from a PDB file.

=cut
sub read {
    my ($self) = @_;

    carp "Not implemented";
    return;
}


################################################################################
__PACKAGE__->meta->make_immutable;
no Moose;
1;
