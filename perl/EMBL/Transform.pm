#!/usr/bin/env perl

=head1 NAME

EMBL::Transform - Represents an affine transformation matrix (4x4)

=head1 SYNOPSIS

 use EMBL::Transform

=head1 DESCRIPTION

An L<EMBL::Transform> can transform L<EMBL::Domain>s or L<EMBL::Assembly>s. It
is compatible with STAMP transformation matrices (3x4) and reads and writes
them.

=head1 SEE ALSO

L<EMBL::Domain>

=cut

################################################################################

package EMBL::Transform;
use EMBL::Root -base, -XXX;

our @EXPORT = qw(onto);

field 'matrix';
field 'string';
field 'file';
field 'tainted';

use overload (
    '*' => 'mult',
    '""' => 'asstring',
    );

use PDL;
use PDL::Matrix;
use PDL::IO::Storable;
use Carp;


################################################################################
=head2 new

 Title   : new
 Usage   : 
 Function: 
 Returns : 
 Args    : -matrix

=cut
sub new () {
    my ($class, %o) = @_;
    my $self = { %o };
    bless $self, $class;
    $self->_undash;

    if (defined $self->{string}) {
        $self->_from_string;
    } elsif (defined $self->{file}) {
        $self->_from_file;
    } elsif (defined $self->{matrix}) {
        # Note that matrix is set
        $self->tainted(1);
    } else {
        $self->reset();
    }
    return $self;
} # new


################################################################################
=head2 reset

 Title   : reset
 Usage   : $transf->reset;
 Function: Resets the 'transformation' to the identity;
 Example : $transf->reset;
 Returns : The new value of matrix, i.e. an identity.
 Args    : NA

Resets the internal matrix

=cut
sub reset {
    my $self = shift;
    $self->tainted(0);
    return $self->matrix(idtransform());
}

################################################################################
=head2 idtransform

 Title   : idtransform
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :

Identity transformation matrix

=cut
sub idtransform {
    return mpdl [ [1,0,0,0], [0,1,0,0], [0,0,1,0], [0,0,0,1] ];
} # identity


################################################################################
=head2 mult

 Title   : mult
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :

Matrix multiplication. Order of operations mattters.

=cut
sub mult {
    my ($self, $other) = @_;
    unless (ref($other) eq __PACKAGE__) {
        carp "Need to mult() objects of own type: " . __PACKAGE__ . "\n";
        return undef;
    }
    my $m = $self->matrix x $other->matrix;
    return new EMBL::Transform(-matrix=>$m);
} # mult


################################################################################
=head2 invert

 Title   : invert
 Usage   : $trans->invert
 Function: Inverts the current matrix
 Example : $trans->invert
 Returns : $self
 Args    : NA

=cut
sub invert {
   my ($self) = @_;
   return unless $self->tainted;
   my $i = $self->matrix->inv;
   $self->{matrix} .= $i;
   return $self;

} # invert

################################################################################
=head2 transform

 Title   : transform
 Usage   : $trans->transform($point);
 Function: Applies this transformation matrix to some L<PDL::Matrix>
 Example : my $point123 = mpdl(1,2,3,1)->transpose; 
           my $transformed = $trans->transform($p)->transpose;
 Returns : A 4xn L<PDL::Matrix>
 Args    : thing - a 4xn L<PDL::Matrix>

Apply this transform to some point, or even a matrix (affine multiplication)

If the thing needs to be transpose()'d, that is up to you to do that (before and
after).

=cut
sub transform {
    my ($self, $thing) = @_;
    return $self->{matrix} x $thing;
} # transform


################################################################################
=head2 asstring

 Title   : asstring
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut
sub asstring {
    my ($self) = @_;
    return $self->{matrix};
} # asstring


################################################################################
=head2 ascsv

 Title   : ascsv
 Usage   :
 Function:
 Example :
 Returns : 
 Args    : -explicit - even print if only the identity matrix

For saving, CSV format

=cut
sub ascsv {
    my ($self, %o) = @_;
    return "" unless $self->tainted || defined $o{-explicit};

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
} # print


################################################################################
=head2 _from_file

 Title   : _from_file
 Usage   : $self->_from_file();
 Function:
 Example :
 Returns : 
 Args    :

See L<_from_string>

=cut
sub _from_file {
    my ($self) = @_;
    my $filepath = $self->file;
    chomp $filepath;
    unless (-s $filepath) {
        carp "Cannot load transformation: $filepath\n";
        return undef;
    }
    my $rasc = zeroes(4,4);
    # Overwrite with 3x4 from file (using rasc() from PDL )
    $rasc->rasc($filepath);
    # Put a 1 in the cell 3,3 (bottom right) for affine matrix multiplication
    $rasc->slice('3,3') .= 1;

    # Finally, make it an mpdl, 
    $self->{matrix} = mpdl $rasc;
    $self->tainted(1);
    return $self;
} # _from_file


################################################################################
=head2 _from_string

 Title   : _from_string
 Usage   : $self->_from_string();
 Function:
 Example :
 Returns : 
 Args    :


The transformation is just a 3x4 text table.

This is what you would get from STAMP, after removing { and }

I.e. it's CSV format, whitespace-separated, one row per line.

=cut
sub _from_string {
    my ($self) = @_;
    my $str = $self->string;
    my $rasc = zeroes(4,4);
    # Overwrite with 3x4 from string
    my @lines = split /\n/, $str;
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
    # Put a 1 in the cell 3,3 (bottom right) for affine matrix multiplication
    $rasc->slice('3,3') .= 1;

    # Finally, make it an mpdl, 
    $self->{matrix} = mpdl $rasc;
    $self->tainted(1);
    return $self;
} # _from_string


###############################################################################

1;

__END__

