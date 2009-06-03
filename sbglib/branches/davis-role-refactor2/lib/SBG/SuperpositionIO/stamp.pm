#!/usr/bin/env perl

=head1 NAME

SBG::TransformIO::pdl - 

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::IO>, L<SBG::Transform>

=cut

################################################################################

package SBG::TransformIO::stamp;
use Moose;

with 'SBG::IOI';

use PDL::Core qw/zeroes pdl/;
use SBG::Transform;


=head2 type

The sub-type to use for any dynamically created objects. Should be
L<SBG::Transform> or a sub-class of that. Default "L<SBG::Transform>" .

=cut
has '+type' => (
    default => 'SBG::Transform',
    );




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
=head2 read

 Title   : read
 Usage   : 
 Function: 
 Example : 
 Returns : 
 Args    : 

Reads in row-major order

=cut
sub read {
    my ($self) = @_;
    my $fh = $self->fh() or return;

    my @offset;
    my @rows;
    while (<$fh>) { 
        chomp;
        my ($x, $y, $z, $v) = split ' ';
        push @rows, [ $x, $y, $z ];
        push @offset, $v;
    }
    my $type = $self->type();
    return $type->new() unless @rows;

    # Create 3x3 matrix from 9-elem array, transpose from row-order to col-order
    # PDL uses column major order internally, STAMP uses row-major order
    my $mat = pdl(@rows)->transpose;
    my $offset = pdl @offset;
    return $type->new(matrix=>$mat, post=>$offset);

} # read


################################################################################
=head2 write

 Function:
 Example : 
 Returns : 
 Args    : 

Writes in row-major order

=cut
sub write {
    my ($self, $trans) = @_;
    my $fh = $self->fh or return;
    return "" if $trans->isid() || !defined($trans->matrix);
    my $mat = $trans->matrix;
    my $z = zeroes 4,3;
    # Overwrite 0-matrix : first three columns (rotation)
    # Transposing from col-major to row-major order
    $z->slice('0:2,') .= $trans->matrix->transpose;
    # Overwrite 0-matrix : last column (translation vector)
    $z->slice('3,') .= $trans->offset->transpose;
    # Stringify generic piddle
    my $str= "$z";
    # Remove PDL formatting
    $str=~s/[\[\]]//g;
    $str=~s/\n\n//g;
    print $fh $str, "\n";
    return $self;
} # write


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
__PACKAGE__->meta->make_immutable;
1;
