#!/usr/bin/env perl

=head1 NAME

SBG::Transform::PDL - Represents a transformation matrix 

=head1 SYNOPSIS

 use SBG::Transform::PDL

=head1 DESCRIPTION

This wrapper simply adds minor functionality to L<PDL::Transform>


=head1 SEE ALSO

L<PDL::Transform> , L<SBG::TransformI>

http://www.compbio.dundee.ac.uk/manuals/stamp.4.2/node29.html

=cut

################################################################################

package SBG::Transform::PDL;
use Moose;

with 'SBG::TransformI';


# NB overload does not provide dynamic dispatch
# Not sufficient to simply override, e.g. 'compose()', in subclass
# Need to also redefine operator overloading in subclasses
use overload (
    'x'  => 'apply', 
    '!'  => 'inverse', 
    '==' => 'equals',
    '""' => 'stringify',
    );

use PDL::Transform;
use PDL::Core qw/zeroes pdl/;
use PDL::MatrixOps qw/identity/;
use PDL::Ufunc qw/all/;

# To be Storable
use PDL::IO::Storable;

use Moose::Autobox;
use List::Util qw/reduce/;


# rotation matrix
subtype 'SBG.rotation' 
    => as 'PDL',
    => where { $_->dim(0) == 3 && $_->dim(1) == 3 },
    ;

# translation vector
subtype 'SBG.translation' 
    => as 'PDL',
    => where { $_->dim(0) == 3 },
    ;


################################################################################
# Accessors


################################################################################
=head2 rotation

 Function: 
 Example : 
 Returns : 
 Args    : 

The 3x3 rotation matrix, in row-major order

=cut
has 'rotation' => (
    is => 'ro',
    isa => 'SBG.rotation',
    lazy_build => 1,
    );
sub _build_rotation { identity 3 }


################################################################################
=head2 translation

 Function: 
 Example : 
 Returns : 
 Args    : 

The 1x3 translation vector (row vector)

=cut
has 'translation' => (
    is => 'ro',
    isa => 'SBG.translation',
    lazy_build => 1,
    );
sub _build_translation { zeroes 3 }


################################################################################
=head2 _transform

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
has '_transform' => (
    is => 'ro',
    isa => 'PDL::Transform',
    handles => [qw/stringify/],
    lazy_build => 1,
    );
sub _build__transform { t_linear(dims=>3) }


################################################################################
=head2 BUILD

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub BUILD {
    my ($self) = @_;
    
    if ($self->has_matrix) {
        my ($rot, $transl) = _

        my $mat = $self->matrix;
        $self->rotation($mat->slice('0:2,0:2'));
        # NB slicing is in column-major order by default, unless PDL::Matrix
        if ($mat->isa('PDL::Matrix')) {
            $self->translation($mat->slice('0:2,3')->squeeze);
        } else {
            $self->translation($mat->slice('3,0:2')->squeeze);
        }
    }

# TODO also need to build up matrix, when component given separate

    # Map rotation=>matrix, translation=>post, for passing to PDL::Transform
    my %params;
    $params{matrix} = $self->rotation if $self->has_rotation;
    $params{post} = $self->translation if $self->has_translation;
    # Create a PDL::Transform, which aliased field names
    $self->transform(t_linear(%params, dims=>3)) if %params;


} # BUILDARGS


################################################################################
=head2 inverse

 Function: Returns the inverse of the given L<SBG::Transform::PDL>
 Example : my $newtransf = $origtrans->inverse;
 Returns : Returns the inverse L<SBG::Transform::PDL>, 
 Args    : L<SBG::Transform::PDL>

Does not modify the current transform. 

=cut
sub inverse {
    my ($self) = @_;
    return $self unless $self->_has_transform;
    my $inv = $self->_transform->inverse;

    # Pack it in a new instance, copying constructing other (Moose) attributes
    my $class = ref $self;
#     $self = $class->new(...)
    $self = $class->new()
    return $self;
}


################################################################################
=head2 apply

 Function:
 Example :
 Returns : 
 Args    :

=cut
sub apply {
    my ($self, $other) = @_;
    return $other unless $self->_has_transform;
    my $t = $self->_transform;

    my $t = $self

    # Call the parent's compose() on the same arguments
    my $prod = super();
    # Looking up the class, instead of assuming it, allows sub-classing later
    my $class = ref $self;
    return $class->new(transform=>$prod);

}


################################################################################
=head2 equals

 Function:
 Example :
 Returns : 
 Args    :


=cut
sub equals {
    my ($self, $other) = @_;
    # Don't compare identities
    return 1 unless $self->has_matrix || $other->has_matrix;
    # Unequal if exactly one is defined
    return 0 unless $self->has_matrix && $other->has_matrix;
    # Compare homogoneous 4x4 matrices, cell-by-cell
    return all($self->matrix == $other->matrix);
}


################################################################################
=head2 _components2homog

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub components2homog {
    my ($self) = @_;
    my $homog = zeroes 4,4;

    my ($rotation,$translation) = ($self->rotation, $self

    $homog->slice('0:2,0:2') .= $rotation;
    # Column-major order, since zeroes() returns a non-PDL::Matrix
    $homog->slice('3,0:2') .= $translation;
    # Final 1 in bottom-right for homogenous coords
    $homog->slice('3,3') .= 1;
    return $homog;
}


################################################################################
=head2 _homog2components

 Function: 
 Example : 
 Returns : Array of ($rotation, $translation) matrices
 Args    : L<PDL> or L<PDL::Matrix> of 4x4, homogenous


=cut
sub _homog2components {
    my ($homog) = @_;
    # Convert back from row-major to PDL's col-major
    my $rotation = $homog->slice('0:2,0:2');
    my $translation;
    # NB slicing is in column-major order by default, unless PDL::Matrix
    if ($homog->isa('PDL::Matrix')) {
        $translation = $homog->slice('0:2,3')->squeeze;
    } else {
        $translation = $homog->slice('3,0:2')->squeeze;
    }
    return ($rotation, $translation);
} 


################################################################################
=head2 _compose_through

 Function: 
 Example : 
 Returns : 
 Args    : 


TODO UPDATE

=cut
sub _compose_through {
    my ($self,) = @_;
    return $self unless $self->_iscomposite();
    my $transforms = $self->_transform->{params}{clist};
    $transforms = $transforms->grep(sub { $_ });
    my $homogenous = $transforms->map(sub { $_->_pdl2homog() });
    my $prod = reduce { $a x $b } @$homogenous;
    $self = $self->_homog2pdl($prod);
    return $self;

} # _compose_through


################################################################################
=head2 _iscomposite

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub _iscomposite {
    my ($self,) = @_;
    return defined $self->_transform->{params}{clist};

} # _iscomposite


###############################################################################
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;


