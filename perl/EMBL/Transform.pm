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

use PDL::Matrix;

use overload (
    '*' => 'multiply',
    '*=' => 'multiplyeq',
    '=' => 'assign',
    );

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


    if ($matrix) {
        $self->{transform} = $matrix;
    } else {
        # Identity 4x4
        $self->{transform} = identity();
    }
    # PDBID/Chain (e.g. 2c6ta ) identifying the representative domain
    $self->{dom} = "";

    return $self;

} # new


sub identity {
    return mpdl [ [1,0,0,0], [0,1,0,0], [0,0,1,0], [0,0,0,1]];
}

sub assign {
    my ($self, $other) = @_;
    return $self->{transform} = $other->{transform};
}

sub multiply {
    my ($self, $other) = @_;
    return $self->{transform} x $other->{transform};
}

sub multiplyeq {
    my ($self, $other) = @_;
    return $self->{transform} = $self->{transform} x $other->{transform};
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
    return $self->{transform} = mpdl $rasc;
}


=head2 AUTOLOAD

 Title   : AUTOLOAD
 Usage   : $obj->member_var($new_value);
 Function: Implements get/set functions for member vars. dynamically
 Returns : Final value of the variable, whether it was changed or not
 Args    : New value of the variable, if it is to be updated

Overrides built-in AUTOLOAD function. Allows us to treat member vars. as
function calls.

=cut

sub AUTOLOAD {
    my ($self, $arg) = @_;
    our $AUTOLOAD;
    return if $AUTOLOAD =~ /::DESTROY$/;
    my ($pkg, $file, $line) = caller;
    $line = sprintf("%4d", $line);
    # Use unqualified member var. names,
    # i.e. not 'Package::member', rather simply 'member'
    my ($field) = $AUTOLOAD =~ /::([\w\d]+)$/;
    $self->{$field} = $arg if defined $arg;
    return $self->{$field} || '';
} # AUTOLOAD


###############################################################################

1;

__END__
