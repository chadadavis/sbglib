#!/usr/bin/env perl

=head1 NAME

SBG::GeometricHash - 

=head1 SYNOPSIS

 use SBG::GeometricHash;
 my $h = new SBG::GeometricHash;
 $h->put(...,$model_object);
 %candidates = $h->at($points);


=head1 DESCRIPTION

3D geometric hash, for indexing things described by points in 3D, e.g. molecular
 structures.


=head1 SEE ALSO

1. Wolfson, H. & Rigoutsos, I. Geometric hashing: an overview. Computational
Science & Engineering, IEEE 4, 10-21(1997).

The interface is based on L<Moose::Autobox::Hash>

       at
       put
       exists
       keys
       values
       kv
       slice
       meta
       print
       say

=cut

################################################################################

package SBG::GeometricHash;

use PDL::Lite;
use PDL::Core;
use PDL::Basic qw/sequence/;
use PDL::Primitive qw/random/;
use PDL::Matrix;
use PDL::MatrixOps;
use PDL::Ufunc;
use PDL::Transform;
use PDL::NiceSlice;


# _gh is a hash of ArrayRef
sub new {
    my ($class, %self) = @_;
    my $self = { %self };
    bless $self, $class;
    $self->{_gh} ||= {};
    $self->{binsize} ||= 1;
    return $self;
}



################################################################################
# Public


################################################################################
=head2 exists

 Function: 
 Example : 
 Returns : 
 Args    : 

NB if an observation is more than covered by some known model, then it is
considered maximally covered. For example, if a previous model with 5 points has
been saved and an observation with three points is queried, and all three of
those points match, then the three points are all satisfied, even if the model
has two additional points not present in the observation. The inverse, however,
is not true.

To get all the scores for all of the potential model matches, see L<at>

=cut
sub exists {
    my ($self,@points) = @_;

    my %h = $self->at(@points);
    # Get models that cover all points
    my @fullmatches = grep { @points == $h{$_} } keys %h;
    return unless @fullmatches;
    return wantarray ? @fullmatches : $fullmatches[0];
}


sub class {
    my ($self,@points) = @_;
    my $class = $self->exists(@points);
    return unless $class;
    my @a = split /,/, $class; # /
    return $a[0];

}


# What should be returned here?
# TODO
sub keys {
    my ($self) = @_;

}


################################################################################
=head2 at

 Function: 
 Example : 
 Returns : 
 Args    : $model a L<PDL::Matrix> of dimension nx3

Returns a hash of votes for specific models.

=cut
sub at {
    my ($self,@points) = @_;

    # Get an array of points into a matrix;
    my $model = _model(@points);

    # TODO add rotation to _basis
#     # Determine a basis transformation, to put model in a common frame of ref
#     my $t = _basis($model, 0, 1);
#     # Transform all points using this basis
#     $model = $t->apply($model);

    # Binning
    $model = $self->_quantize($model);

    return $self->_votes($model);

} # at


sub _votes {
    my ($self, $model) = @_;
    my $gh = $self->{'_gh'};
    my %votes;
    # For each 3D point, hash it and append the model name to that point's list
    for (my $i = 0; $i < $model->dim(1); $i++) {
        # Each row is a 3D point
        my $point = $model(,$i);
        my $models = $gh->{$point} || [];
        $votes{$_}++ for @$models;
    }
    return %votes;
}


################################################################################
=head2 put

 Function: 
 Example : 
 Returns : $modelid
 Args    : 

If no model name is provided, generic class ID numbers will be created.
=cut 
sub put { 
    my ($self,$modelid, @points) = @_;
    our $classid;
    $modelid ||= ++$classid;

    # Get an array of points into a matrix;
    my $model = _model(@points);

    # For each pair of points, define a basis and hash all the points
    for (my $i = 0; $i < @points; $i++) {
        for (my $j = 0; $j < @points; $j++) {        
            $self->_one_basis($modelid, $model, $i, $j);
            
# TODO DES abort this until rotations working:
            last;
        }
        last;
    }
        
    return $modelid;

} # put



################################################################################
# Private


sub _one_basis {
    my ($self,$modelid, $model, $i, $j) = @_;

    # TODO add rotation to _basis
#     # Determine a basis transformation, to put model in a common frame of ref
#     my $t = _basis($model, $i, $j);
#     # Transform all points using this basis
#     $model = $t->apply($model);

    # Binning
    $model = $self->_quantize($model);

    for (my $p = 0; $p < $model->dim(1); $p++) {
        # Each row is a 3D point
        my $point = $model(,$p);
        $self->_append($point, $modelid, $i, $j);
    }
}


sub _append {
    my ($self, $point, $modelid, $i, $j) = @_;

    # For each 3D point, hash it and append the model name to that point's list
    my $gh = $self->{'_gh'};
    $gh->{$point} ||= [];
    push @{ $gh->{$point} }, "${modelid},${i},${j}";
}


################################################################################
=head2 _model

 Function: 
 Example : 
 Returns : 
 Args    : 

Create a matrix model for a set of mpdl points, remove homogenous coords.
Result is row-major order, i.e. each row is a 3D point. 

=cut
sub _model {
    my (@points) = @_;
    my $m = pdl(@points)->squeeze;
    # Drop last column, assuming these were homogenous vectors
    # (i.e. take columns, 0,1,2 (x,y,z)
    $m = $m(0:2,);
    return $m;

} # _model


################################################################################
=head2 _quantize

 Function: 
 Example : 
 Returns : 
 Args    : 

For example, with binsize=5, converts:

 [ 6.1724927 -1.3568784]
 [-5.2222763  18.794775]

to:

 [ 5  0]
 [-5 15]

NB The bin that straddles 0 will be twice the size it should be.  This is
because floor() is not applicable to PDL data. Instead we use PDL::long() which
just converts to an integer.

=cut
# NB This is done inplace. I.e. $matrix is modified
sub _quantize {
    my ($self, $matrix, $binsize) = @_;
    $binsize ||= $self->{binsize};

    # Convert to integer in the middle step, throws away less significant digits
    return $binsize * long ($matrix / $binsize);
}


################################################################################
=head2 _basis

 Function: 
 Example : 
 Returns : 
 Args    : 

Determine the basis transformation, which is the transformation that puts the
first point at the origin and the second point at X=1


=cut
sub _basis {
    my ($model, $i, $j) = @_;

   # First two points define a basis vector.
   # This is transformed to the unit vector from (0,0,0)->(1,0,0), in the X axis
    my $b0 = $model(,$i);
    my $b1 = $model(,$j);

    # Vector from $b0 to $b1
    my $diff = $b1 - $b0;
    my $dist = _dist($diff);

    # Angles of rotation from coordinates axes, in degrees
    my $ryz = 60; # about x axis
    my $rzx = 45; # about y axis
    my $rxy = 0; # about z axis (no rotation, as we'll already be in X axis)

    # A Linear transformation, including translation, scaling, rotation
    my $t = t_linear(dims=>3,
                     pre=>zeroes(3)-$b0, # translation, s.t. b0 moves to origin
                     scale=>1/$dist, # scale, s.t. vector $b0 -> $b1 is length 1
#                      rot=>[$ryz, $rzx, $rxy], # rotation about 3 axes
    );

    return $t;

} # _basis


# Vector length, Euclidean
sub _vlen {
    # Square root of the sum of the squared coords
    return sqrt sumover($_[0]**2)->sclr;
}


# If $other not given, the origin (0,0,0) is assumed
sub _sqdist {
    my ($selfc, $otherc) = @_;
    $otherc = zeroes(3) unless defined($otherc);
    # Vector diff
    my $diff = $selfc - $otherc;
    my $squared = $diff ** 2;
    # Squeezing allows this to work either on column or row vectors
    my $sum = sumover($squared->squeeze);
    # Convert to scalar
    return $sum->sclr;
}

sub _dist {
    return sqrt(_sqdist(@_));
}


################################################################################
1;

