#!/usr/bin/env perl

=head1 NAME

SBG::Domain::Atoms - Represents a domain of a protein structure. 

=head1 SYNOPSIS

 use SBG::Domain::Atoms;

=head1 DESCRIPTION

A generic class that implements only the L<SBG::DomainI> interface

=head1 SEE ALSO

L<SBG::DomainI>

=cut



package SBG::Domain::Atoms;
use Moose;

# Defines what must be implemented to represent a 3D structure
with (
    'SBG::DomainI',
    );


use overload (
    '""' => 'stringify',
    '==' => 'equal',
    fallback => 1,
    );

use Carp;

use SBG::DomainIO::pdb;
use SBG::U::RMSD;


=head2 atom_type

A regular expression for the atom type code, e.g. 'CA' of atoms to read in from
a PDB coordinate file.

NB that e.g. 'CD' would match 'CD1' and 'CD2' unless you say 'CD ' (i.e. with an
explicit trailing space). Likewise, 'C' will match 'CA', 'CB', 'CG', 'CG1',
'CG2', etc

=cut
has 'atom_type' => (
    is => 'rw',
    default =>  'CA ',
    );


# Coords of center of mass
has '_centroid' => (
    is => 'rw',
    isa => 'PDL',
    );


has 'residues' => (
    is => 'ro',
    isa => 'Maybe[ArrayRef[Int]]',
    );


=head2 BUILD

 Function: 
 Example : 
 Returns : 
 Args    : 

Uses L<SBG::DomainIO::pdb> to generate a coordinate file, from which coordinates
are read back in. Does not read from a native PDB file, as the domain descriptor
may simply refer to a subset of a PDB entry (e.g. single chain or chain
segment).

=cut
sub BUILD {
    my ($self) = @_;
    my $io = new SBG::DomainIO::pdb(tempfile=>1);
    $io->write($self);
    # Open the file for reading now
    $io = new SBG::DomainIO::pdb(file=>$io->file,
                                 atom_type=>$self->atom_type,
                                 residues=>$self->residues,
        );
    
    # Get the coords directly from the IO obj.
    my $coords = $io->coords;
    $self->coords($coords);
    $self->_centroid(SBG::U::RMSD::centroid($coords));

    # Loaded from a temp PDB file, so clear that path
    $self->clear_file;

    return $self;
}




=head2 centroid

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub centroid {
    my ($self,) = @_;
    return $self->_centroid;

} # centroid



=head2 overlap

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub overlap {
    carp "overlap() not implemented in " . __PACKAGE__;
    return;
}



__PACKAGE__->meta->make_immutable;
no Moose;
1;

