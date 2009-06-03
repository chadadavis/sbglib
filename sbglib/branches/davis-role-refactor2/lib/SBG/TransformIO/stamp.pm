#!/usr/bin/env perl

=head1 NAME

SBG::TransformIO::pdl - 

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::IOI>, L<SBG::TransformI>

http://www.compbio.dundee.ac.uk/manuals/stamp.4.2/node29.html

=cut

################################################################################

package SBG::TransformIO::stamp;
use Moose;

with 'SBG::IOI';

use SBG::TransformI;
use PDL::Core qw/zeroes pdl/;


=head2 type

The sub-type to use for any dynamically created objects. Should do 
L<SBG::TransformI>

=cut
has '+type' => (
    required => 1,
    default => 'SBG::Transform::Homog',
    );


################################################################################
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
        chomp;
        # Called like this, split discards any leading whitespace, leaving:
        # (X,Y,Z,T)
        push @rows, [ split ' ' ];
    }
    my $type = $self->type();
    return $type->new() unless @rows;
    # Required for homogenous coords
    push @rows, [ 0, 0, 0, 1 ];
    my $mat = pdl(@rows);

    return $type->new(matrix=>$mat);

} # read


################################################################################
=head2 write

 Function:
 Example : 
 Returns : 
 Args    : 

Writes in row-major order

=cut
sub write {
    my ($self, $trans) = @_;
    my $fh = $self->fh or return;
    return "" unless $trans->has_matrix;
    my $mat = $trans->matrix;

    my $line_format = '%10.5f ' x 4;
    my $block_format = ($line_format . "\n") x 3;
    # NB PDL indexes in column-major order
    # I.e. columns 0:3 and rows 0:2 , which is a 3x4 STAMP matrix
    my @array = $mat->slice('0:3,0:2')->list();
    printf $fh $block_format, @array;
    return $self;
}


################################################################################
__PACKAGE__->meta->make_immutable;
1;
