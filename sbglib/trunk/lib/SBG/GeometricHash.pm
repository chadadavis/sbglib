#!/usr/bin/env perl

=head1 NAME

SBG::GeometricHash - A 3-dimensional geometric hash, with optional point labels

=head1 SYNOPSIS

 use SBG::GeometricHash;
 my $h = new SBG::GeometricHash;
 $h->put(...,$model_object);
 %candidates = $h->at($points);


=head1 DESCRIPTION

3D geometric hash, for indexing things described by points in 3D, e.g. atomic
structures.

Each point can have a label.  When querying with a label, the labels must much.
If a model is saved with labels, but the query provides no labels, any model
will match, labelled or not.  I.e. using a label requires matching, but if you
don't care about labels, they will not get in the way.


Provides a method exact() that allows one to only retrieve models that were the
same size (same # of points) as the current query.  For simply finding models
that are a superset of the current query, the method class() is appropriate.


Heavily based on L<PDL>. Works with L<PDL> or L<PDL::Matrix> data.

Uses L<PDL::Transform> for the transformation work.


NB testing single points in axis is problematic if X==Y==0 This results in not
being able to create a non-ambiguous basis for the transformations.


=head1 SEE ALSO

1. Wolfson, H. & Rigoutsos, I. Geometric hashing: an overview. Computational
Science & Engineering, IEEE 4, 10-21(1997).


=cut

package SBG::GeometricHash;

use strict;
use warnings;

use PDL::Lite;
use PDL::Core qw/pdl zeroes/;
use PDL::Basic qw/sequence/;
use PDL::Primitive qw/random/;
use PDL::Ufunc;
use PDL::Transform;
use PDL::NiceSlice;

use Math::Trig qw/rad2deg/;
use Math::Round qw/nearest/;

# TODO DEL
use SBG::U::Log qw/log/;


################################################################################
=head2 new

 Function: 
 Example : 
 Returns : 
 Args    : 

_gh is a HashRef of ArrayRef

=cut
sub new {
    my ($class, %self) = @_;
    my $self = { %self };
    bless $self, $class;
    $self->{_gh} ||= {};
    $self->{binsize} ||= 1;
    $self->{classid} = 0;
    return $self;
}


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

NB this matches when a query is completely covered by a known hashed model.
But it does not imply that a query covers the corresponding model.
I.e. the answer is always a superset, but not exact. For that, see L<exact>

=cut
sub exists {
    my ($self,$points,$labels) = @_;

    my %h = $self->at($points, $labels);
    # Get models that cover all points of the query
    my @fullcovers = grep { @$points == $h{$_} } keys %h;
    return unless @fullcovers;
    return wantarray ? @fullcovers : $fullcovers[0];
}

 
################################################################################
=head2 class

 Function: The name of the model/class, without any appended basis indices 
 Example : 
 Returns : 
 Args    : 


=cut
sub class {
    my ($self,$points, $labels) = @_;
    my $class = $self->exists($points, $labels);
    return unless $class;
    my @a = split / /, $class;
    return $a[0];
}


################################################################################
=head2 exact

 Function: Matches exactly
 Example : 
 Returns : 
 Args    : 

i.e a model is only matched when it is the same size as the query

i.e. query is a subset of found model, and found model is subset of query

=cut
sub exact {
    my ($self,$points, $labels) = @_;
    # Models that cover the query
    my @covers = $self->exists($points, $labels);
    # Models the same size as the query:
    my @a;
    my ($bijection) = grep { @a=split; $a[1] == @$points } @covers;
    log()->debug($bijection || '<none>');
    return unless $bijection;
    # Remove end of label, containing basis indices
    my @f = split / /, $bijection;
    return $f[0];

}



################################################################################
=head2 at

 Function: 
 Example : 
 Returns : 
 Args    : $points an ArrayRef of L<PDL> (coordinates)

Returns a hash of votes for specific models.

=cut
sub at {
    my ($self,$points,$labels) = @_;

    # Get an array of points into a matrix;
    my $model = _model($points);
    log()->trace($model);

    # Determine a basis transformation, to put model in a common frame of ref
    # Arbitrarily use first three points here, but any three would work
    my $t = _basis($model, 0, 1, 2) or return;
    # Transform all points using this basis
    $model = $t->apply($model);

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
        # No label: try to match any/all
        my @keys = keys %{ $self->{_gh}{$point} };
        # For all labels as keys:
        my @values = map { @{ $self->{_gh}{$point}{$_} } } @keys;
        # Remove duplicates
        return [ _uniq(@values) ];
    }
}


# Make an array uniq (i.e. becomes a 'set'), by stringification (via hashing)
sub _uniq { 
    my %h;
    $h{$_} = 1 for @_;
    return keys %h;
}


# For each point in the query model, add up the votes for all the hashed models
sub _votes {
    my ($self, $model, $labels) = @_;
    my $gh = $self->{'_gh'};
    my %votes;
    # For each 3D point, hash it 
    for (my $i = 0; $i < $model->dim(1); $i++) {
        # Each row is a 3D point (NB list() is quite inefficient)
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
    my ($self, $modelid, $points, $labels) = @_;

    unless (defined $modelid) {
        $self->{'classid'}++;
        $modelid = $self->{'classid'};
    }

    # If each (labelled) object contains multiple points, extract points.  Also
    # assigns the object's label to each point in the object.
    ($points, $labels) = _objs2points($points, $labels);

    # Get an array of points into a matrix;
    my $model = _model($points);

    log()->trace($model);

    # For each triple of points, define one basis,
    # For each basis, transform all points into that basis and hash them
    for (my $i = 0; $i < @$points; $i++) {
        for (my $j = 0; $j < @$points; $j++) {        
            next if $i == $j;
            for (my $k = 0; $k < @$points; $k++) {        
                next if $j == $k || $i == $k;
                $self->_one_basis($modelid, $model, $i, $j, $k, $labels);
            }
        }
    }
        
    return $modelid;

} # put


# Convert an ArrayRef of objects (2D PDL) to an ArrayRef of points (1D PDL)
# Expands labels for object to apply to each point within the object
# Assumes a PDL, not PDL::Matrix
sub _objs2points {
    my ($objs, $labels) = @_;

    my @points;
    my @pointlabels;
    for (my $i = 0; $i < @$objs; $i++) {
        my $o = $objs->[$i];
        my $dim;
        if ($o->isa('PDL::Matrix')) {
            # Row-major indexing
            $dim = $o->dim(0);
            push(@points, $o->slice("$_,")->squeeze) for (0..$dim-1);
        } else {
            # Column-major indexing
            $dim = $o->dim(1);
            push(@points, $o->slice(",$_")->squeeze) for (0..$dim-1);
        }
        push @pointlabels, (($labels->[$i]) x $dim);
    }
    return wantarray ? ([ @points ], [ @pointlabels ]) : [@points];
}


sub _one_basis {
    my ($self,$modelid, $model, $i, $j, $k, $labels) = @_;
#     log()->trace(join(' ', $modelid, $i, $j, $k));
    # Determine a basis transformation, to put model in a common frame of ref
    my $t = _basis($model, $i, $j, $k) or return;
    # Transform all points using this basis
    $model = $t->apply($model);

    # Binning
    $model = $self->_quantize($model);

    for (my $p = 0; $p < $model->dim(1); $p++) {
        # Each row is a 3D point
        # is list() more inefficient than stringification?
        my $point = join(' ',$model(,$p)->list);
        my $label = $labels ? $labels->[$p] : '';
        $self->_append($point, $label, $modelid, $model->dim(1), $i, $j, $k);
    }
}


sub _append {
    my ($self, $point, $label, $modelid, $size, $i, $j, $k) = @_;
    $label ||= 'undef';
    # For each 3D point, hash it and append the model name to that point's list
    my $gh = $self->{'_gh'};
    $gh->{$point} ||= {};
    $gh->{$point}{$label} ||= [];
    push @{ $gh->{$point}{$label} }, join(' ', $modelid, $size, $i, $j, $k);
}


################################################################################
=head2 _model

 Function: 
 Example : 
 Returns : 
 Args    : ArrayRef[PDL] each piddle might be a single point or multiple

Create a matrix model for a set of coordinates.

Removes hmogenous coords, i.e. drops 4th dimension, if it exists;

Result is row-major order, i.e. each row is a 3D point. 

=cut
sub _model {
    my ($points) = @_;
    my $m = pdl($points)->squeeze;
    $m = $m->clump(1,2) if $m->dims == 3;
    # Drop last column, assuming these were homogenous vectors
    # (i.e. take columns, 0,1,2 (x,y,z)
    # NB this is a PDL (not PDL::Matrix), so indexed in column-major order
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

    # $model_$i is the new origin. 
    # $model_$j will lie on the X-axis
    # $model_$k will lie in the XY-plane

NB TODO DES could also support scaling
But scale just first vector, both vectors separately, or both vectors together?

http://en.wikipedia.org/wiki/Atan2

=cut
sub _basis {
    my ($model, $i, $j, $k) = @_;
#     log()->trace("$i $j $k");

    # $model_$i is the new origin
    my $translation = zeroes(3) - $model(,$i);
    my $t_o = t_offset($translation);

    # $model_$j will lie on the X-axis
    my $b1 = $model(,$j) - $model(,$i);
    # $model_$k will lie in the XY-plane
    my $b2 = $model(,$k) - $model(,$i);

    # First rotation, from Y-axis toward X-axis, about Z-axis
    # This gets b1 into the XZ plane
    my ($x,$y,$z) = $b1->list;
    if (0==$y && 0==$x) {
        log()->debug("Skipping undefined basis: Y,X both 0");
        return;
    }

    # Angle between line (0,0)->(x,y) and the x-axis, which is the angle to
    # rotate by, from the y-axis, toward the x-axis, about the z-axis
    my $ry2x = rad2deg atan2 $y, $x;
#     log()->trace("y=>x $ry2x deg ($x,$y,$z)");
    my $t_ry2x = t_rot([0,0,$ry2x],dims=>3);
    $b1 = $t_ry2x->apply($b1);
    $b2 = $t_ry2x->apply($b2);

    # Second rotation, from X-axis toward Z-axis, about Y-axis Negative rotation
    # here, to get b1 onto the XY plane. Now b1 will be in the X-axis, since XZ
    # plane and XY plane intersect at the X-axis.
    ($x, $y, $z) = $b1->list;

    if (0==$z && 0==$x) {
        log()->debug("Skipping undefined basis: Z,X both 0");
        return;
    }

    # $z = rise and $x = run here, since we're rotating backward. Sign still
    # needs to be negative as well, however.  This is the angle between the line
    # (0,0)->(x,z) and the X-axis (not Z-axis). Since PDL::Transform rotates
    # from X-axis, toward Z-axis, sign is negative
    my $rx2z = - rad2deg atan2 $z, $x;
#     log()->trace("x=>z $rx2z deg ($x,$y,$z)");
    my $t_rx2z = t_rot([0,$rx2z,0],dims=>3);
    $b1 = $t_rx2z->apply($b1);
    $b2 = $t_rx2z->apply($b2);

    # Third rotation, from Z-axis to Y-axis, about X-axis
    # This will leave $b1 on the X-axis, $b0 is rotated into the XY plane
    ($x, $y, $z) = $b2->list;

    if (0==$z && 0==$y) {
        log()->debug("Skipping undefined basis: Z,Y both 0");
        return;
    }

    # Angle between line (0,0)->(y,z) and the y-axis, which is the angle to
    # rotate by, from the z-axis, toward the y-axis, about the x-axis
    my $rz2y = rad2deg atan2 $z, $y;
#     log()->trace("z=>y $rz2y deg ($x,$y,$z)");
    my $t_rz2y = t_rot([$rz2y,0,0],dims=>3);

    # Composite transform:
    my $rot = [ $rz2y, $rx2z, $ry2x ];
#     log()->trace("Rot @$rot");
    # Right-to-left composition of transformation matrices
    my $t = $t_rz2y x $t_rx2z x $t_ry2x x $t_o;
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
    $otherc = zeroes(3) unless defined $otherc;
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

