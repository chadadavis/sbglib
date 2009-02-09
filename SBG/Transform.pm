#!/usr/bin/env perl

=head1 NAME

SBG::Transform - Represents an affine transformation matrix (4x4)

=head1 SYNOPSIS

 use SBG::Transform

=head1 DESCRIPTION

This simply translates between STAMP (I/O) and PDL (internal) matrix
crepresentations.

An L<SBG::Transform> can transform L<SBG::Domain>s or L<SBG::Assembly>s. It
is compatible with STAMP transformation matrices (3x4) and reads and writes
them.

=head1 SEE ALSO

L<SBG::Domain>

=cut

################################################################################

package SBG::Transform;
use Moose;
with 'SBG::Storable';
with 'SBG::Dumpable';

use Carp;
use PDL::Lite;
use PDL::Matrix;
use PDL::IO::Storable;
use PDL::Ufunc;

use SBG::Types;

use overload (
    'x' => '_mult',
    '""' => 'ascsv',
    '==' => '_equal',
    );


################################################################################
# Accessors

=head2 matrix

The 4x4 affine transformation matrix
=cut
has 'matrix' => (
    is => 'rw',
    isa => 'PDL::Matrix',
    lazy_build => 1,
    );
# Differntiate between identity matrix and non-identity
after 'matrix' => sub {
    (shift)->_tainted(1);
};

=head2 string

Create a matrix from a CSV string
=cut
has 'string' => (
    is => 'ro',
    isa => 'Str',
    );

=head2 file

Create a matrix from a CSV file
=cut
has 'file' => (
    is => 'ro',
    isa => 'SBG.File',
    );
# Update/parse matrix after a file/string set
after qw/string file/ => sub {
    (shift)->load();
};

has '_opcount' => (
    is => 'rw',
    isa => 'Int',
    default => 0,
    );

has '_tainted' => (
    is => 'rw',
    isa => 'Bool',
    default => 0,
    );



################################################################################
=head2 _build_matrix

 Function:
 Example :
 Returns : 
 Args    :

Identity transformation matrix, 4x4

=cut
sub _build_matrix {
    return mpdl [ [1,0,0,0], [0,1,0,0], [0,0,1,0], [0,0,0,1] ];
}


################################################################################
=head2 reset

 Function: Resets the 'transformation' to the identity;
 Example : $transf->reset;
 Returns : The new value of matrix, i.e. an identity.
 Args    : NA

Resets the internal matrix

=cut
sub reset {
    my $self = shift;
    $self->_tainted(0);
    $self->opcount(0);
    return $self->matrix(_build_matrix());
}


################################################################################
=head2 invert

 Function: Inverts the current matrix
 Example : $trans->invert
 Returns : $self
 Args    : NA

See L<inverse>

=cut
sub invert {
   my ($self) = @_;
   return unless $self->_tainted;
   my $m = $self->matrix;
   my $i = $m->inv;
   # TODO test this syntax, need functional syntax
   # $m .= $i; # Assign underlying object
   # $self->matrix($m);
   $self->{matrix} .= $i;
   return $self;

} # invert


################################################################################
=head2 inverse

 Function: Returns the inverse of the given L<SBG::Transform>
 Example : my $newtransf = $origtrans->inverse;
 Returns : Returns the inverse L<SBG::Transform>, 
 Args    : NA

Does not modify the current transform. 

See L<invert>

=cut
sub inverse {
    my ($self) = @_;
    return new SBG::Transform unless $self->_tainted;
    return new SBG::Transform(matrix=>$self->matrix->inv);
}


################################################################################
=head2 relativeto

 Function: Aransformation of A (or $self), relative to B
 Example : my $A_relative_to_B = $A_transform->relativeto($B_transform);
 Returns : 
 Args    : Two L<SBG::Transform>, i.e. $self an $some_other

Creates a new L<SBG::Transform> without modifying existing ones. I.e the result
is what A would be, in B's frame of reference, but B will not be modified. To
put many transformations into one frame of reference:

 my $refernce = shift @transforms;
 foreach (@transforms) {
    $_ = $_->relativeto($reference);
 }

NB this is the cumulative transformation, i.e. absolute

=cut
sub relativeto ($$) {
    my ($self, $ref) = @_;
    # Always apply transform on the left
    my $t = $ref->inverse x $self;
    return $t;

} # relativeto


################################################################################
=head2 transform

 Function: Applies this transformation matrix to some L<PDL::Matrix>
 Example : my $point123 = mpdl(1,2,3,1)->transpose; 
           my $transformed = $trans->transform($p)->transpose;
 Returns : A 4xn L<PDL::Matrix>
 Args    : thing - a 4xn L<PDL::Matrix>

Apply this transform to some point, or even a matrix (affine multiplication)

If the thing needs to be B<transpose()>'d, that is up to you to do that (before and
after).

=cut
sub transform {
    my ($self, $thing) = @_;
    return $thing unless $self->_tainted;
    if (ref($self) eq ref($thing)) {
        return $self->_mult($thing);
    } else {
        # Matrix multiplication using PDL
        return $self->matrix x $thing;
    }
} # transform


################################################################################
=head2 ascsv

 Function:
 Example : print $transf->ascsv(force=>1)
 Returns : 
 Args    : force - even print if only the identity matrix

For saving, CSV format
Appends newline B<\n>

=cut
sub ascsv {
    my ($self, %o) = @_;
    return "" unless $self->_tainted || defined $o{force};

    my $mat = $self->matrix;
    my ($n,$m) = $mat->dims;
    my $str;
    # Don't do the final row (affine). Stop at $n - 1
    for (my $i = 0; $i < $n - 1; $i++) {
        for (my $j = 0; $j < $m; $j++) {
            $str .= sprintf("%10.5f ", $mat->at($i,$j));
        }
        $str .= "\n";
    }
    return $str;
} # ascsv


################################################################################
=head2 _load

 Function: Sets matrix based on previously assigned L<string> or L<file>
 Example : 
 Returns : $self
 Args    : NA

=cut
sub _load {
    my ($self,@args) = @_;
    my $rasc;

    if ($self->file) {
        $rasc = $self->_load_file();
    } elsif ($self->string) {
        $rasc = $self->_load_string();
    } else {
        carp "Need either a 'string' or 'file' to load";
    }
    # Put a 1 in the cell 3,3 (bottom right) for affine matrix multiplication
    $rasc->slice('3,3') .= 1;
    # Finally, make it a PDL::Matrix
    $self->matrix(mpdl $rasc);
    return $self;

} # _load


################################################################################
=head2 _load_file

 Function: Overwrite with 3x4 from file (using rasc() from PDL )
 Example :
 Returns : 
 Args    :

=cut
sub _load_file {
    my ($self) = @_;
    my $rasc = zeroes(4,4);
    $rasc->rasc($self->file);
    return $rasc;
}


################################################################################
=head2 _load_string

 Function:
 Example :
 Returns : 
 Args    :


=cut
sub _load_string {
    my ($self) = @_;
    my $rasc = zeroes(4,4);
    my @lines = split /\n/, $self->string;
    # Skip empty lines
    @lines = grep { ! /^\s*$/ } @lines;
    for (my $i = 0; $i < @lines; $i++) {
        # Whitespace-separated
        my @fields = split /\s+/, $lines[$i];
        # Skip emtpy fields (i.e. when the first field is just whitespace)
        @fields = grep { ! /^\s*$/ } @fields;
        for (my $j = 0; $j < @fields; $j++) {
            # Column major order, i.e. (j,i) not (i,j)
            $rasc->slice("$j,$i") .= $fields[$j];
        }
    }
    return $rasc;
} # _load_string


################################################################################
=head2 _mult

 Function:
 Example :
 Returns : 
 Args    :

Matrix multiplication. Order of operations mattters.

=cut
sub _mult {
    my ($self, $other) = @_;
    unless (ref($self) eq ref($other)) {
        carp "Types differ: " . ref($self) . ' vs. ' . ref($other);
        return;
    }
    # Don't waste time multiplying identities
    return $self unless $other->_tainted;
    return $other unless $self->_tainted;
    my $m = $self->matrix x $other->matrix;
    # Carry over the opcount (debuggin)
    return new SBG::Transform(matrix=>$m, 
                              opcount=>1 + $self->opcount + $other->opcount);
} # _mult



################################################################################
=head2 _equal

 Function:
 Example :
 Returns : 
 Args    :


=cut
sub _equal ($$) {
    my ($self, $other) = @_;
    return all($self->matrix == $other->matrix);
}


###############################################################################

1;

__END__

