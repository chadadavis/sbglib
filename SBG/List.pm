#!/usr/bin/env perl

package SBG::List;
use base qw(Exporter);
our @EXPORT = qw(
min
max
sum
avg
stddev
sequence
rearrange
thresh
put
);

use File::Temp qw(tempfile);
use File::Basename;
use File::Spec::Functions qw/rel2abs catdir/;

################################################################################


# Minimum of a list
sub min {
    my $x = shift @_;
    $x = $_ < $x ? $_ : $x for @_;
    return $x;
}

# Maximum of a list
sub max {
    my $x = shift @_;
    $x = $_ > $x ? $_ : $x for @_;
    return $x;
}

# Sum of a list
sub sum {
    my $x = 0;
    $x += $_ for @_;
    return $x;
}

# Average of a list
sub avg {
    # Check if we were given a reference
    my $r = $_[0];
    my @list = (ref $r) ? @$r : @_;
    return 0 unless @list;
    my $sum = 0;
    $sum += $_ for @list;
    return $sum / @list;
}

# Stddev of a list
sub stddev {
    # Check if we were given a reference
    my $r = $_[0];
    my @list = (ref $r) ? @$r : @_;
    return 0 unless @list > 1;
    my $sum = 0;
    my $avg = avg(\@list);
    for (my $i = 0; $i < @list; $i++) {
        $sum += ($list[$i] - $avg)**2;
    }
    return sqrt($sum/(@list - 1));
}

# Creates a sequence of numbers (similar to in R)
sub sequence {
    my ($start, $inc, $end) = @_;
    my @a;
    for (my $i = $start; $i <= $end; $i+=$inc) {
        push @a, $i;
    }
    return @a;
}

# Support for named function parameters. E.g.:
# func(-param1=>2, -param3=>"house");
sub rearrange  {
    # The array ref. specifiying the desired order of the parameters
    my $order = shift;
    # Make sure the first parameter, at least, starts with a -
    return @_ unless (substr($_[0]||'',0,1) eq '-');
    # Make sure we have an even number of params
    push @_,undef unless $#_ %2;
    my %param;
    while( @_ ) {
        (my $key = shift) =~ tr/a-z\055/A-Z/d; #deletes all dashes!
        $param{$key} = shift;
    }
    map { $_ = uc($_) } @$order; # for bug #1343, but is there perf hit here?
    # Return the values of the hash, based on the keys in @$order
    # I.e. this return the values sorted by the order of the keys
    return @param{@$order};
} # rearrange

# Converts analogue values to binary, given a threshold
# Something like this is probably already provided by the PDL
sub thresh {
    my ($ref, $thresh) = @_;
    for (my $i = 0; $i < @$ref; $i++) {
        $ref->[$i] = $ref->[$i] > $thresh;
    }
}

# Prints an arry with indices in tabular form in a temp text file
# (This is also comprehensible to gnuplot)
sub put {
    my ($array) = @_;
#     my ($fh, $out) = tempfile("/tmp/disoconsXXXXXXXXXX", UNLINK=>!$::DEBUG);
    my ($fh, $out) = tempfile("/tmp/disoconsXXXXXXXXXX", UNLINK=>1);
    for (my $i = 1; $i < @$array; $i++) {
        print $fh "$i ", $array->[$i], "\n";
    }
    close $fh;
    return $out;
}

################################################################################
1;
__END__


