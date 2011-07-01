#!/usr/bin/env perl

=head1 NAME

SBG::TransformIO::pdl - 

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::IO>, L<SBG::Transform>

=cut

################################################################################

package SBG::TransformIO::pdl;
use Moose;
with 'SBG::IOI';

use PDL::Core qw/pdl/;

use SBG::TransformI;


=head2 objtype

The sub-objtype to use for any dynamically created objects. Should be
L<SBG::TransformI> implementor.

=cut
# has '+objtype' => (
#     required => 1,
#     default => 'SBG::Transform::PDL',
#     );

sub BUILD {
    my ($self) = @_;
    $self->objtype('SBG::Transform::PDL') unless $self->objtype;
}


################################################################################
=head2 read

 Title   : read
 Usage   : 
 Function: 
 Example : 
 Returns : 
 Args    : 

Reads native output format of L<PDL::Transform>

=cut
sub read {
    my ($self) = @_;
    my $fh = $self->fh or return;

    my $post_offset;
    my @rows;
    while (my $line = <$fh>) { 
        if ($line =~ /Post-add:\s+\[(.*?)\]/) {
            $post_offset = pdl split(' ', $1);
            next;
        }
        if ($line =~ /Forward matrix/) {
            <$fh>;
            # Read three lines
            @rows = map { scalar <$fh> } 1..3;
            # Clean out [ and ] and \n
            @rows = map { s/[\[\]\n]//g; $_ } @rows;
            # Each of the three rows is now an array ref of three elements
            @rows = map { [ split(' ') ] } @rows;
            last;
        }
    }

    my $objtype = $self->objtype();
    return $objtype->new() unless @rows;
    # Create 3x3 matrix from 9-elem array
    my $mat = pdl @rows;
    # (OK if $post_offset is still undef here)
    return $objtype->new(matrix=>$mat, post=>$post_offset);

} # read


################################################################################
=head2 write

 Function:
 Example : 
 Returns : 
 Args    : 

Writes using native output format of L<PDL::Transform>

# TODO composite assume PDL::Transform implementation here

=cut
sub write {
    my ($self, $trans) = @_;
    my $fh = $self->fh or return;
    # Combine composite transforms into single transformation matrix
    $trans = $trans->composite();
    print $fh $trans;
    return $self;
} # write


################################################################################
__PACKAGE__->meta->make_immutable;
1;
