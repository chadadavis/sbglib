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

Each point can have a label.  When querying with a label, the labels must much.
If a model is saved with labels, but the query provides no labels, any model
will match, labelled or not.  I.e. using a label requires matching, if you don't
care about labels, they don't get in the way, though.



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

use Math::Trig qw/rad2deg/;
use Math::Round qw/nearest/;

use SBG::Log;

################################################################################

################################################################################
=head2 new

 Function: 
 Example : 
 Returns : 
 Args    : 

_gh is a hash of ArrayRef

=cut
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
    my ($self,$points,$labels) = @_;

    my %h = $self->at($points, $labels);
    # Get models that cover all points
    my @fullmatches = grep { @$points == $h{$_} } keys %h;
    return unless @fullmatches;
    return wantarray ? @fullmatches : $fullmatches[0];
}

 
# TODO DOC
# The name of the model/class without the indices used for the basis
sub class {
    my ($self,$points, $labels) = @_;
    my $class = $self->exists($points, $labels);
    return unless $class;
    my @a = split / /, $class;
    return $a[0];
}


# What should be returned here?
# The true keys (coords), or the conceptual keys (model IDs)
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
    my ($self,$points,$labels) = @_;

    # Get an array of points into a matrix;
    my $model = _model($points);
    $logger->trace($model);

# TODO DEL
    print STDERR 'before basis', $model;

    # Determine a basis transformation, to put model in a common frame of ref
    my $t = _basis($model, 0, 1);
    # Transform all points using this basis
    $model = $t->apply($model);

# TODO DEL
    print STDERR 'at', $model;

    # Binning
    $model = $self->_quantize($model);

    return $self->_votes($model, $labels);

} # at


# Model at a specify point key, possibly matching a label
sub _atkey {
    my ($self, $point, $label) = @_;
    if ($label) {
        # Label must match, if provided
        return $self->{_gh}{$point}{$label};
    } else {
        # No label: match any/all
        my @keys = keys %{ $self->{_gh}{$point} };
        my @values = map { @{ $self->{_gh}{$point}{$_} } } @keys;
        return [ _uniq(@values) ];
    }
}


sub _uniq { 
    my %h;
    $h{$_} = 1 for @_;
    return keys %h;
}


sub _votes {
    my ($self, $model, $labels) = @_;
    my $gh = $self->{'_gh'};
    my %votes;
    # For each 3D point, hash it and append the model name to that point's list
    for (my $i = 0; $i < $model->dim(1); $i++) {
        # Each row is a 3D point
        my $point = join(' ',$model(,$i)->list);
        my $label = $labels ? $labels->[$i] : '';
        my $candidates = $self->_atkey($point, $label) || [];
        $votes{$_}++ for @$candidates;
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
    my ($self,$modelid, $points, $labels) = @_;
    our $classid;
    $modelid ||= ++$classid;

    # Get an array of points into a matrix;
    my $model = _model($points);

    $logger->trace($model);

    # For each pair of points, define a basis and hash all the points
    for (my $i = 0; $i < @$points; $i++) {
        for (my $j = 0; $j < @$points; $j++) {        
            next if $i == $j;
            $self->_one_basis($modelid, $model, $i, $j, $labels);
        }
    }
        
    return $modelid;

} # put



################################################################################
# Private


sub _one_basis {
    my ($self,$modelid, $model, $i, $j, $labels) = @_;
    $logger->trace(join(' ', $modelid, $i, $j));
    # Determine a basis transformation, to put model in a common frame of ref
    my $t = _basis($model, $i, $j);
    # Transform all points using this basis
    $model = $t->apply($model);


# TODO DEL
#     if ($i == 0 && $j == 1) {
        print STDERR "one_basis $i $j", $model;
#     }

    # Binning
    $model = $self->_quantize($model);

    for (my $p = 0; $p < $model->dim(1); $p++) {
        # Each row is a 3D point
        my $point = join(' ',$model(,$p)->list);
        my $label = $labels ? $labels->[$p] : '';
        $self->_append($point, $label, $modelid, $i, $j);
    }
}


sub _append {
    my ($self, $point, $label, $modelid, $i, $j) = @_;

    # For each 3D point, hash it and append the model name to that point's list
    my $gh = $self->{'_gh'};
    $gh->{$point} ||= {};
    $gh->{$point}{$label} ||= [];
    push @{ $gh->{$point}{$label} }, join(' ', $modelid, $i, $j);
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
    my ($points) = @_;
    my $m = pdl(@$points)->squeeze;
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

NB The bin that straddles 0 is twice as large, since it holds the numbers that approach it from both sides. 

=cut
sub _quantize {
    my ($self, $matrix, $binsize) = @_;
    $binsize ||= $self->{binsize};
    my $qmat = zeroes($matrix->dims);
    # For rows
    for (my $i = 0; $i < $matrix->dim(1); $i++) {
        my @row = $matrix(,$i)->list;
        # Round
        @row = map { nearest($binsize, $_) } @row;
        $qmat(,$i) .= pdl(@row);
    }
    return $qmat
    # Convert to integer in the middle step, throws away less significant digits
#     return $binsize * long ($matrix / $binsize);

}


################################################################################
=head2 _basis

 Function: 
 Example : 
 Returns : 
 Args    : 

Determine the basis transformation, which is the transformation that puts the
first point at the origin and the second point at X=1

   # The first two points define a basis vector.
   # This is transformed to a vector of fixed lenth along one coord. axis

=cut
sub _basis {
    my ($model, $i, $j) = @_;
    $logger->trace("$i $j");

    # Vector from origin, as long as $model_$i to $model_$j
    my $end = $model(,$j) - $model(,$i);
    # Shift vector's beginning the origin using this translation
    my $translation = zeroes(3) - $model(,$i);
    my $t_o = t_offset($translation);

    # scale, s.t. vector is fixed length
    # (NB this scaling factor should be larger than the binsize)
    my $scale = 10.0 / _dist($end);
    my $t_s = t_scale($scale, dims=>3);
    $end = $t_s->apply($end);
    my ($x, $y, $z) = $end->list; 

    # Angles of rotation from coordinate axes, in degrees, clockwise

    # first, from y toward x, about z axis, projects into XZ plane
    $logger->warn("Y and X both 0, basis undefined") if 0==$y && 0==$x;    
    my $ry2x = rad2deg atan2 $y, $x;
    $logger->trace("y=>x $ry2x deg ($x,$y,$z)");
    my $t_ry2x = t_rot([0,0,$ry2x],dims=>3);
    # Update, before performing subsequent rotations, as coords have changed
    $end = $t_ry2x->apply($end);
    ($x,$y,$z) = $end->list;

    # second, from x toward z, about y axis, projects into ZY plane
    $logger->warn("X and Z both 0, basis undefined") if 0==$x && 0==$z;
    my $rx2z = rad2deg atan2 $x, $z;
    $logger->trace("x=>z $rx2z deg ($x,$y,$z)");

# TODO DEL
    if (0) {
    my $t_rx2z = t_rot([0,$rx2z,0],dims=>3);
    # Update, before performing subsequent rotations, as coords have changed
    $end = $t_rx2z->apply($end);
    ($x,$y,$z) = $end->list;
    $logger->warn("Z and Y both 0, basis undefined") if 0==$z && 0==$y;
    my $rz2y = rad2deg atan2 $z, $y;
    my $t_rz2y = t_rot([$rz2y,0,0],dims=>3);
    $logger->trace("z=>y $rz2y deg ($x,$y,$z)");

    my $rot = [$rz2y,$rx2z,$ry2x];
    }

    # No need for rotation Z to Y, as we'll be in Z-axis already
    my $rot = [0,$rx2z,$ry2x];
    my $t_r = t_rot($rot, dims=>3);


    $logger->trace("Translation:$translation");
    $logger->trace("Scale:$scale");
    $logger->trace("Rot @$rot");

    # Don't scale before rotating, as the rotation assumes not-yet scaled coords
#     my $t = $t_s x $t_r x $t_o;
    my $t = $t_r x $t_s x $t_o;
#     my $t = $t_rz2y x $t_rx2z x $t_ry2x x $t_s x $t_o;
#     my $t = $t_o x $t_s x $t_rz2y x $t_rx2z x $t_ry2x;
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

