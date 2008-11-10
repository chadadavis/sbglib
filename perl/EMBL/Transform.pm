#!/usr/bin/env perl

=head1 NAME

EMBL::Transform - 

=head1 SYNOPSIS


=head1 DESCRIPTION



=head1 BUGS

None known.

=head1 REVISION

$Id: Prediction.pm,v 1.33 2005/02/28 01:34:35 uid1343 Exp $

=head1 APPENDIX

Details on functions implemented here are described below.
Private internal functions are generally preceded with an _

=cut

################################################################################



package EMBL::Transform;

use PDL;
use PDL::Matrix;

# use overload (
#     '*' => 'mult',
#     '*=' => 'multeq',
#     '=' => 'assign',
#     );

use lib "..";



################################################################################
=head2 new

 Title   : new
 Usage   : 
 Function: 
 Returns : 
 Args    :

=cut

sub new {
    my ($class, $matrix) = @_;
    my $self = {};
    bless $self, $class;


    if (defined $matrix) {
        $self->{matrix} = $matrix;
    } else {
        # Identity 4x4
#         $self->{matrix} = pdl (1,0);
#         $self->{matrix} = mpdl (1,0);
        $self->{matrix} = EMBL::Transform::id();
    }
    # PDBID/Chain (e.g. 2c6ta ) identifying the representative domain
    $self->{dom} = "";

    return $self;

} # new


sub id {
    return mpdl [ [1,0,0,0], [0,1,0,0], [0,0,1,0], [0,0,0,1] ];
}

sub assign {
    my ($self, $other) = @_;
    return $self->{matrix} = $other->{matrix};
}

sub mult {
    my ($self, $other) = @_;
    return $self->{matrix} x $other->{matrix};
}

sub multeq {
    my ($self, $other) = @_;
    return $self->{matrix} = $self->{matrix} x $other->{matrix};
}

sub load {
    my ($self, $filepath) = @_;

    chomp $filepath;
    print STDERR "load: $filepath\n";
    unless (-f $filepath && -r $filepath && -s $filepath) {
        print STDERR "Cannot read transformation from: $filepath\n";
        return undef;
    }

    # This transformation is just a 3x4 text table, from STAMP, without any { }
    my $rasc = zeroes(4,4);
    # Overwrite with 3x4 from file 
    $rasc->rasc($filepath);
    # Put a 1 in the cell 3,3 (bottom right) for affine matrix multiplication
    $rasc->slice('3,3') .= 1;

    # Finally, make it an mpdl, 
    return $self->{matrix} = mpdl $rasc;
}



###############################################################################

1;

__END__
