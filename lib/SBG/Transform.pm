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

use PDL::Lite;
use PDL::Core;
use PDL::Matrix;
use PDL::MatrixOps;
use PDL::IO::Storable;
use PDL::IO::Misc;
use PDL::Ufunc;

use List::MoreUtils qw/mesh/;

use SBG::Types;
use SBG::Log;

use overload (
    'x' => '_mult',
    '""' => 'ascsv',
    '==' => '_equal',
    );


# STAMP score fields
our @keys = qw/Domain1 Domain2 Sc RMS Len1 Len2 Align Fit Eq Secs I S P/;


################################################################################
# Accessors

=head2 matrix

The 4x4 affine transformation matrix
Using homogenous coordinates (ie 4D)
Default is the identity matrix
=cut
has 'matrix' => (
    is => 'rw',
    isa => 'PDL::Matrix',
    required => 1,
    default => sub { mpdl identity 4 },
    trigger => sub { my $self = shift; $self->_tainted(1) if @_ },
    );


=head2 string

Create a matrix from a CSV string
=cut
has 'string' => (
    is => 'ro',
    isa => 'Str',
    trigger => sub { (shift)->_load },
    );


=head2 file

Create a matrix from a CSV file
=cut
has 'file' => (
    is => 'ro',
    isa => 'SBG.File',
    trigger => sub { (shift)->_load },
    );


# Note if not-yet-modified
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
=head2 id

 Function: Represents the transformation of a domain onto itself
 Example : my $id_trans = SBG::Transform::id();
 Returns : L<SBG::Transform>
 Args    : NA

NB: The difference between this and just using C<new()>, which also uses and
identity transformation, is that this method explicitly sets the STAMP scores
for the transformation to their maximum values. I.e. this is to explicitly say
that one is transforming a domain onto itself and that the identity transform is
high-scoring. The C<new()> just uses the identity transform as a convenient
default and sets no scores on the transform.

=cut
sub id {
    my $self = new SBG::Transform();
    $self->{'Sc'} = 10;
    $self->{'RMS'} = 0;
    $self->{'I'} = 100;
    $self->{'S'} = 100;
    $self->{'P'} = 0;
    return $self;
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
 Returns : L<SBG::Transform>
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
# sub apply 
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
 Args    : 

For saving, CSV format
Appends newline B<\n>

=cut
sub ascsv {
    my ($self) = @_;
    return "" unless $self->_tainted && defined($self->matrix);

    my $mat = $self->matrix;
    my ($n,$m) = $mat->dims;

    print STDERR "mat:$mat:\n" unless ($n && $m);

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
=head2 asstamp

 Function: 
 Example : 
 Returns : 
 Args    : 

%     No.  Domain1         Domain2         Sc     RMS    Len1 Len2  Align NFit Eq. Secs.   %I   %S   P(m)
%Pair   1  1qf6            1nj8            0.67   1.81    110  268   137   30  26    3   7.69  84.62 1.00e+00


=cut
sub headers {
    my ($self) = @_;
    return "\n" unless $self->_tainted;
    our @keys;
    my $str = '';
    $str .= join("\t", qw/% No/, @keys) . "\n";
    my @vals = map { defined($self->{$_}) ? $self->{$_} : '' } @keys;
    $str .= join("\t", qw/%Pair 1/, @vals) . "\n";
    return $str;
}

################################################################################
=head2 _load

 Function: Sets matrix based on previously assigned L<string> or L<file>
 Example : 
 Returns : $self
 Args    : NA

=cut
sub _load {
    my ($self,@args) = @_;
    my $rasc = identity(4);

    if ($self->file) {
        $rasc = $self->_load_file();
    } elsif ($self->string) {
        $rasc = $self->_load_string();
    } else {
        $logger->error("Need either a 'string' or 'file' to load");
    }
    return $self unless defined($rasc);
    # Put a 1 in the cell 3,3 (bottom right) for affine matrix multiplication
    $rasc->slice('3,3') .= 1;
    # Finally, make it a PDL::Matrix
    $self->matrix(mpdl $rasc);

    return $self;

} # _load


################################################################################
=head2 _load_file

 Function: Loads a STAMP transformation from a file
 Example :
 Returns : 
 Args    :

The file is expected to contain a STAMP score line beginning with 'Pair' etc.

# TODO DES duplicated with STAMP::stamp

# TODO DES metadata is stored directly in this object w/o accessors

# TODO DES Need separate functions to parse:
1 Header lines with meta data
1.1 Stamp block(s)
1.1.1 Transformation matrix, 3 lines

=cut
sub _load_file {
    my ($self, $file) = @_;
    $file ||= $self->file;
    my $fh;
    unless (open $fh, $file) {
        $logger->error("Cannot read: $file ($!)");
        return;
    }
    my $matstr;
    our @keys;

    # Load metadata from header lines
    my %fields;
    # First find the "Pair" line
    while (<$fh>) {
        next unless /(\%\s)*Pair\s+\d+\s+(.*)$/;
        my @fields = split /\s+/, $2;
        @fields = @fields[0..$#keys];
        unless (@fields == @keys) {
            $logger->error("Expected ", scalar(@keys), " keys. Got: @fields");
            return;
        }

        # Hash @keys to @t
        %fields = List::MoreUtils::mesh @keys, @fields;
        # Now find the stamp block
        while (<$fh>) {
            # Match opening { but no closing } this ensures a transform block
            next unless /\{[^}]+$/;
            # The three lines that make up the 3x4 transformation matrix
            $matstr .= <$fh> . <$fh> . <$fh>;
        }
    }
    unless ($matstr) {
        $logger->error("No transformation found in ", $file);
        return;
    }

    # Store the meta data directly in this object
    $self->{$_} = $fields{$_} for keys %fields;

    return $self->_load_string($matstr);
}


################################################################################
=head2 _load_string

 Function:
 Example :
 Returns : 
 Args    :

Sets the internal transformation matrix, given a string like:

"
  -0.64850   -0.34315    0.67949  -26.63386 
   0.71843    0.01913    0.69534  -24.89855 
  -0.25160    0.93909    0.23412    6.94888 
"

White-space is collapsed.

=cut
sub _load_string {
    my ($self, $str) = @_;
    $str ||= $self->string;
    unless ($str) {
        $logger->error("No string to parse");
        return;
    }
    my $rasc = identity(4);
    $logger->trace("In:\n", $str);
    my @lines = split /\n/, $str;
    # Skip empty lines
    @lines = grep { ! /^\s*$/ } @lines;
    # Only take 3 lines
    for (my $i = 0; $i < 3; $i++) {
        # Whitespace-separated
        my @fields = split /\s+/, $lines[$i];
        # Skip emtpy fields (i.e. when the first field is just whitespace)
        @fields = grep { ! /^\s*$/ } @fields;
        # Only only take 4 fields
        for (my $j = 0; $j < 4 ; $j++) {
            # Column major order, i.e. (j,i) not (i,j)
            $rasc->slice("$j,$i") .= $fields[$j];
        }
    }
    $logger->trace("Out:\n",$rasc);

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
# sub compose {
sub _mult {
    my ($self, $other) = @_;
    unless (ref($self) eq ref($other)) {
        $logger->error("Types differ: " . ref($self) . ' vs. ' . ref($other));
        return;
    }
    # Don't waste time multiplying identities
    return $self unless $other->_tainted;
    return $other unless $self->_tainted;
    my $m = $self->matrix x $other->matrix;

    return new SBG::Transform(matrix=>$m);
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
    return 0 unless defined($other) && blessed($self) eq blessed($other);
    # Equal if neither has yet been set
    return 1 unless $self->_tainted || $other->_tainted;
    return all($self->matrix == $other->matrix);
}


###############################################################################
__PACKAGE__->meta->make_immutable;
1;

__END__

