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

use overload (
    '*' => 'mult',
    '""' => 'asstring',
    );

use PDL;
use PDL::Matrix;
use Carp;

use EMBL::DB;


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
        # Already there
    } else {
        $self->{matrix} = idtransform();
    }
    return $self;
} # new


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
        carp "Need to mult() objects of own type: " . __PACKAGE__;
        return undef;
    }
    my $m = $self->matrix x $other->matrix;
    return new EMBL::Transform(-matrix=>$m);
} # mult


################################################################################
=head2 transform

 Title   : transform
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :

Apply this transform to some point, or even a matrix (affine multiplication)

If the thing needs to be transpose()'d, that is up to you to do that first.

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
=head2 asstamp

 Title   : asstamp
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :

For saving, STAMP format

=cut
sub asstamp {
    my $self = shift;
    my $str;
    my $mat = $self->matrix;

    my ($n,$m) = $mat->dims;
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
    return $self;
} # _from_string














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
#         $trans->cache($srcdom,$destdom);
        return $trans;
    }

}

# TODO put in STAMP.pm
sub stamp {
    my ($srcdom, $destdom) = @_;
    print STDERR "\tTransform::stamp($srcdom,$destdom)\n";
    my $cmd = "./transform.sh $srcdom $destdom";
    my $transfile = `$cmd`;
    return (-s $transfile) ? $transfile : undef;
}










###############################################################################

1;

__END__


# TODO
# Get from database
sub dbfetch {
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


# TODO
# Wrrite back to database
sub dbcache {
    my ($self, $srcdom, $destdom) = @_;
    print STDERR "\tTransform::cache($srcdom,$destdom)\n";
    # Write back to DB

}

