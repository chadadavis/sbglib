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

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(onto);

use PDL;
use PDL::Matrix;

use overload (
    '*' => 'mult',
#     '*=' => 'multeq',
#     '=' => 'assign',
    '""' => 'asstring',
    );

use lib "..";
use EMBL::DB;


# TODO export all the static methods

# TODO use Spiffy
# Document fields (e.g. 'matrix')


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


# Apply this transformation to a point and return transformed point
sub applyto {
    my ($pt) = @_;
    # transpose()s point before and after matrix multiplication


}


sub onto {
    my ($srcdom, $destdom) = @_;
    
    print STDERR "\tonto()$srcdom -> $destdom\n";

    # Lookup in DB
    my $transstr = fetch($srcdom, $destdom);
    if ($transstr) { 
        my $t = new EMBL::Transform();
        $t->loadstr($transstr);
        return $t;
    }

    # Otherwise run stamp
    my $transfile = stamp($srcdom, $destdom);
    # If that succeeded: load it, cache it, return it
    if ($transfile) {
        my $trans = new EMBL::Transform();
        $trans->loadfile($transfile);
        $trans->cache($srcdom,$destdom);
        return $trans;
    }

}

sub cache {
    my ($self, $srcdom, $destdom) = @_;
    print STDERR "\tTransform::cache($srcdom,$destdom)\n";
    # Write back to DB

}

sub stamp {
    my ($srcdom, $destdom) = @_;
    print STDERR "\tTransform::stamp($srcdom,$destdom)\n";
    my $cmd = "./transform.sh $srcdom $destdom";
    my $transfile = `$cmd`;
    return (-s $transfile) ? $transfile : undef;
}

sub fetch {
    my ($srcdom, $destdom) = @_;
    print STDERR "\tTransform::fetch($srcdom,$destdom)\n";
    # TODO use Config::IniFiles;
    my $dbh = dbconnect("pc-russell12", "davis_trans") or return undef;
    # Static handle, prepare it only once
    our $fetch_sth;
    $fetch_sth ||= $dbh->prepare("select trans " .
                                 "from trans ".
                                 "where (src=? and dest=?)");
    $fetch_sth or return undef;
    if (! $fetch_sth->execute($srcdom, $destdom)) {
        print STDERR $fetch_sth->errstr;
        return undef;
    }
    my ($transstr) = $fetch_sth->fetchrow_array();
    return $transstr;
}


sub i {
    my $self = shift;
    return $self->{matrix}->at(@_);
}

# Static function (i.e. class method)
sub id {
    return mpdl [ [1,0,0,0], [0,1,0,0], [0,0,1,0], [0,0,0,1] ];
}

# For printing
sub asstring {
    my ($self) = @_;
    return $self->{matrix};
}

# For saving, STAMP format
sub print {
    my $self = shift;
    my $str;
    my $mat = $self->{matrix};

    my ($n,$m) = $mat->dims;
    # Don't do the final row (affine). Stop at $n - 1
    for (my $i = 0; $i < $n - 1; $i++) {
        for (my $j = 0; $j < $m; $j++) {
            $str .= sprintf("%10.5f ", $mat->at($i,$j));
        }
        $str .= "\n";
    }
    return $str;
        
}

sub assign {
    my ($self, $other) = @_;
    return $self->{matrix} = $other->{matrix};
}

sub mult {
    my ($self, $other) = @_;
    my $m = $self->{matrix} x $other->{matrix};
    return new EMBL::Transform($m);
}

# Apply this transform to some point
# If the thing needs to be transpose()'d, do that first
sub transform {
    my ($self, $thing) = @_;
    return $self->{matrix} x $thing;
}

sub multeq {
    my ($self, $other) = @_;
    $self->{matrix} = $self->{matrix} x $other->{matrix};
    return $self;
}

# This transformation is just a 3x4 text table, from STAMP, without any { }
sub loadfile {
    my ($self, $filepath) = @_;
    chomp $filepath;
    unless (-s $filepath) {
        print STDERR "Cannot load transformation: $filepath\n";
        return undef;
    }


    my $rasc = zeroes(4,4);
    # Overwrite with 3x4 from file 
    $rasc->rasc($filepath);
    # Put a 1 in the cell 3,3 (bottom right) for affine matrix multiplication
    $rasc->slice('3,3') .= 1;

    # Finally, make it an mpdl, 
    $self->{matrix} = mpdl $rasc;
    return 1;
}

sub loadstr {
    my ($self, $str) = @_;
    # This transformation is just a 3x4 text table, from STAMP, without any { }
    my $rasc = zeroes(4,4);
    # Overwrite with 3x4 from string
    my @lines = split /\n/, $str;
    @lines = grep { ! /^\s*$/ } @lines;
    for (my $i = 0; $i < @lines; $i++) {
        my @fields = split /\s+/, $lines[$i];
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
    return 1;
}


###############################################################################

1;

__END__
