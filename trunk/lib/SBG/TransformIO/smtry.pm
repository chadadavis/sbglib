#!/usr/bin/env perl

=head1 NAME

SBG::TransformIO::smtry - Reads symmetry operator matrices from a PBD file 

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::IOI>, L<SBG::TransformI>

=cut



package SBG::TransformIO::smtry;
use Moose;

with 'SBG::IOI';

use Carp;

use PDL::Core qw/zeroes pdl/;

use SBG::TransformI;
use SBG::Transform::Affine;

=head2 objtype

The sub-objtype to use for any dynamically created objects. Should do 
L<SBG::TransformI>

=cut
# has 'objtype' => (
#     required => 1,
#     default => 'SBG::Transform::Affine',
#     );


sub BUILD {
    my ($self) = @_;
    $self->objtype('SBG::Transform::Affine') unless $self->objtype;
}



=head2 read

 Title   : read
 Usage   : 
 Function: 
 Example : 
 Returns : 
 Args    : 

Reads in row-major order

=cut
sub read {
    my ($self) = @_;
    my $fh = $self->fh() or return;

    # Homogenous transformation matrix 4x4
    my @rows;

    while (<$fh>) {
        next unless /^REMARK 290   SMTRY(.)  (..)(..........)(..........)(..........)(...............)/;
        my $row_i = $1;
        my $matrix_i = $2;
        my ($x,$y,$z,$t) = ($3, $4, $5, $6);
        push @rows, [ $x, $y, $z, $t ];        
           
        if (@rows == 3) {
        	# Add a row for homogenous coords
        	push @rows, [ 0, 0, 0, 1 ];
        	my $mat = pdl(@rows);
        	my $objtype = $self->objtype();     	
        	return $objtype->new(matrix=>$mat);
        }	
    }
    return;
    
} # read


sub write {
    my ($self, $trans) = @_;
    carp "Not implemented";
    return;
}



__PACKAGE__->meta->make_immutable;
1;
