#!/usr/bin/env perl

package SBG::List;
use base qw(Exporter);
our @EXPORT_OK = qw(
min
max
sum
avg
stddev
sequence
nsort
union
intersection
rearrange
thresh
which
whicheval
whichfield
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

sub nsort {
    return sort { $a <=> $b } @_;
}

# Recursivel flattens an array (nested array of arrays) into one long array
sub _expand_array { 
    my @a;
    foreach (@_) {
        push @a, ref($_) ? _expand_array(@$_) : $_;
    }
    return @a;
}


# Returns unique elements from list(s)
# Not sorted
# NB if these are objects, string equality is used to determine uniqueness
sub union {
    my @a = _expand_array @_;
    my %names = map { $_ => $_ } @a;
    # Return values, rather than keys.
    # values are unmodified, whereas keys have been stringified
    return values %names;
}

# Input an array of arrays, i.e. intersection([1..5],[3..7],...)
# Works with any numbers of arrays
# Objects are compared with string equality, 
# but objects, rather than strings, are returned, if given as input
sub intersection {
    my $n = @_;
    my %counts;
    my %things;
    foreach my $a (@_) {
        $counts{$_}++ for @$a;
        # Overwrites an string-equal objects previously seen
        $things{$_} = $_ for @$a;
    }
    my @common = grep { $counts{$_} == $n } keys %counts;
    my @objs = map { $things{$_} } @common;
    return @objs;
}


# Simple which, based on eq
# Returns index
sub which {
    my ($val, @a) = @_;
    my @t = grep { $a[$_] eq $val } 0..$#a;
    return wantarray ? @t : shift @t;
}

# Return indices i for which $exp is true, foreach $_ in @a
sub whicheval {
    my ($exp, @a) = @_;
    # Use temporary index placeholder
    my @t = grep { $i=$_; $_=$a[$_]; $_=$i if eval($exp) } 0..$#a;
    return wantarray ? @t : shift @t;
}

# Return indices i for which $exp is true when $_ = $a[$i]
sub whichfield {
    my ($field, $val, @a) = @_;
    return whicheval("\$_->{$field} eq \"$val\"", @a);
}

################################################################################
1;
__END__


