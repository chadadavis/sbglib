#!/usr/bin/env perl

=head1 NAME

SBG::Transform - Represents a transformation matrix 

=head1 SYNOPSIS

 use SBG::Transform

=head1 DESCRIPTION

This simply translates between STAMP (I/O) and PDL (internal) matrix
crepresentations.

An L<SBG::Transform> can transform L<SBG::DomainI>s or L<SBG::Complex>s. It
is compatible with STAMP transformation matrices (3x4) and reads and writes
them.

=head1 SEE ALSO

L<SBG::Domain>

=cut

################################################################################

package SBG::Transform;
use Moose;
# Explicitly identify Moose as parent, since also extending Transform
extends qw/Moose::Object PDL::Transform/;

with qw/
SBG::Role::Storable
SBG::Role::Dumpable
/;


# hack required to subclass PDL::Transform
our @EXPORT_OK = @PDL::Transform::EXPORT_OK;
our %EXPORT_TAGS = (Func=>[@PDL::Transform::EXPORT_OK]);

use overload (
#     'x'  => 'compose',  # overrides PDL::Transform
#     '""' => 'stringify',  # overrides PDL::Transform
    '==' => '_equal',
    );

use PDL::Core qw/zeroes pdl/;
use PDL::Transform;
use PDL::IO::Storable;
use PDL::Ufunc qw/all/;

use List::MoreUtils qw/mesh/;

use SBG::U::Log;
use SBG::Types;


################################################################################
# Accessors


=head2 keys

STAMP score fields

 Domain1 Domain2 Sc RMS Len1 Len2 Align Fit Eq Secs I S P

=cut
our @keys = qw/Domain1 Domain2 Sc RMS Len1 Len2 Align Fit Eq Secs I S P/;
has \@keys => (
    # Each attribute is read-write
    is => 'rw',
    );


=head2 isid

Is identity transformation

=cut 
has 'isid' => (
    is => 'rw',
    );


################################################################################
=head2 matrix

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub matrix {
    my ($self,) = @_;
    return $self->{params}{matrix};
} # matrix


################################################################################
=head2 offset

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub offset {
    my ($self,) = @_;
    return $self->{params}{post};
} # offset


################################################################################
=head2 new

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub new {
    my ($class, %ops) = @_;
    return _load_string($ops{string}) if $ops{string};
    return _load_file($ops{file}) if $ops{file};

    # Moose::Object parent class
    my $self = $class->SUPER::new(%ops);
    # PDL::Transform parent class
    # Explicitly set dimensions to 3, in case no parameters given
    my $trans = defined($ops{transform}) || t_linear(%ops, dim=>3);
    # Merge objects
    $self = { %$self, %$trans };
    # Bless into this class as well
    bless $self, $class;
    return $self;
}


################################################################################
=head2 t_identity

 Function: Represents the transformation of a domain onto itself
 Example : my $id_trans = SBG::Transform::t_identity();
 Returns : L<SBG::Transform>
 Args    : NA

NB: The difference between this and just using C<new()>, which also uses and
identity transformation, is that this method explicitly sets the STAMP scores
for the transformation to their maximum values. I.e. this is to explicitly say
that one is transforming a domain onto itself and that the identity transform is
high-scoring. The C<new()> just uses the identity transform as a convenient
default and sets no scores on the transform.

=cut
override 't_identity' => sub {
    my $self = new SBG::Transform(
        isid=> 1,
        Sc  => 10,
        RMS => 0,
        I => 100,
        S => 100,
        P => 0,
        );
    return $self;
};
*identity = \&t_identity;
*id = \&t_identity;


################################################################################
=head2 inverse

 Function: Returns the inverse of the given L<SBG::Transform>
 Example : my $newtransf = $origtrans->inverse;
 Returns : Returns the inverse L<SBG::Transform>, 
 Args    : NA

Does not modify the current transform. 

=cut
override 'inverse' => sub {
    my ($self) = @_;
    return $self if $self->isid();
    my $class = ref $self;
    # The inverse PDL::Transform object
    my $transform = $self->PDL::Transform::inverse();
    # Pack in in a SBG::Transform
    $self = new $class(transform=>$transform, %$self);
    return $self;
};


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
=head2 stringify

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
override 'stringify' => sub {
    my ($self)= @_;
    return $self->ascsv;
};


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

    return "" if $self->isid() || !defined($self->matrix);

    my $mat = $self->matrix;
    my $z = zeroes 4,3;
    $z->slice('0:2,') .= $self->{params}{matrix}->transpose;
    $z->slice('3,') .= $self->{params}{post}->transpose;
    my $str= "$z";
    $str=~s/[\[\]]//g;
    $str=~s/\n\n//g;
    return $str;
} # ascsv


################################################################################
=head2 headers

 Function: Print header fields in STAMP format
 Example : 
 Returns : 
 Args    : 

%     No.  Domain1         Domain2         Sc     RMS    Len1 Len2  Align NFit Eq. Secs.   %I   %S   P(m)
%Pair   1  1qf6            1nj8            0.67   1.81    110  268   137   30  26    3   7.69  84.62 1.00e+00


=cut
sub headers {
    my ($self) = @_;
    return "\n" if $self->isid;
    our @keys;
    my $str = '';
    $str .= join("\t", qw/% No/, @keys) . "\n";
    my @vals = map { defined($self->{$_}) ? $self->{$_} : '' } @keys;
    $str .= join("\t", qw/%Pair 1/, @vals) . "\n";
    return $str;
}


################################################################################
=head2 _load_file

 Function: Loads a STAMP transformation from a file
 Example :
 Returns : 
 Args    :

The file is expected to contain a STAMP score line beginning with 'Pair' etc.

# TODO DES duplicated with STAMP::stamp

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
} # _load_file


################################################################################
=head2 _load_string

 Function:
 Example :
 Returns : 
 Args    :

Sets the internal transformation matrix, given new-line separated string like:

 r11 r12 r13 v1
 r21 r22 r23 v2
 r31 r32 r33 v3

E.g.: 

  -0.64850   -0.34315    0.67949  -26.63386 
   0.71843    0.01913    0.69534  -24.89855 
  -0.25160    0.93909    0.23412    6.94888 


=cut
sub _load_string {
    my ($str) = @_;
    unless ($str) {
        $logger->error("No string to parse");
        return;
    }
    $logger->trace("str:\n", $str);

    my @lines = split /\n/, $str;
    # Skip empty lines
    @lines = grep { ! /^\s*$/ } @lines;
    # Only take 3 lines
    for (my $i = 0; $i < 3; $i++) {
        # Whitespace-separated
        my @fields = split /\s+/, $lines[$i];
        # Skip emtpy fields (i.e. when the first field is just whitespace)
        @fields = grep { ! /^\s*$/ } @fields;
        # Only  take 4 fields
        for (my $j = 0; $j < 4 ; $j++) {
            # Column major order, i.e. (j,i) not (i,j)
            $rasc->slice("$j,$i") .= $fields[$j];
        }
    }
    $logger->trace("Out:\n",$rasc);

    return $rasc;
} # _load_string



# TODO DOC
# NB use post=>$offset to apply translation after rotation
sub _parse_matrix {
    my ($self, $str) = @_;
    $str =~ s/[\[\]]//g;
    my @elems= split(' ',$str);
    return unless @elems;

    # Get the last column (the translation components)
    my $offset = [ delete @elems[3, 7, 11] ];
    # Remaining row-order 3x3 rotation matrix
    @elems = grep { defined } @elems;
    # Create 3x3 matrix from 9-elem array, then transpose to column-major order
    my $mat = pdl([@elems[0..2]], [@elems[3..5]], [@elems[6..8]])->transpose;

    return ($mat, $offset);
} # _parse_matrix


################################################################################
=head2 compose

 Function:
 Example :
 Returns : 
 Args    :

Matrix composition.

=cut
override 'compose' => sub {
    my ($self, $other) = @_;
    # Don't waste time multiplying identities
    return $self if $other->isid;
    return $other if $self->isid;

    # Rotations
    my $prod = $self->matrix x $other->matrix;

    # TODO translations ...

    # But this is just a composition, maybe doesn't have a matrix
    return new SBG::Transform(matrix=>$prod);

    # TODO BUG missing translations
};


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
    return 1 if $self->isid && $other->isid;
    return all($self->matrix == $other->matrix);
    return all($self->offset == $other->offset);
}


###############################################################################
__PACKAGE__->meta->make_immutable;
1;


