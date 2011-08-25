#!/usr/bin/env perl

=head1 NAME

SBG::U::List - Utilities on Arrays

=head1 SYNOPSIS

 use SBG::U::List qw/min max .../;

or

use Moose::Autobox;
use autobox ARRAY => 'SBG::U::List';

my $list = [ 1 .. 3, [ rand(10) ]];
print join "\n", $list->sum, $list->stddev, $list->mean, $list->avg, ...;


=head1 DESCRIPTION

Most functions are just wrappers around L<List::Util> or L<List::MoreUtils>
. Nothing is exported by default. 

All functions take both arrays and array refs, which may contain nested arrays.

Methods returning lists will return an ArrayRef when called in scalar context.


=head1 SEE ALSO

L<List::Utils> , L<List::MoreUtils>

=cut

package SBG::U::List;
use Carp;

use Moose::Autobox;

use List::Util qw/reduce/;
use List::MoreUtils;

use base qw(Exporter);

our @EXPORT = qw(
);
our @EXPORT_OK = qw(
    sum
    min
    max
    reduce
    uniq
    flatten
    swap
    nsort
    argmax
    argmin
    mean
    avg
    wtavg
    dotproduct
    median
    variance
    stddev
    sequence
    lcp
    intersection
    union
    pairs
    pairs2
    reorder
    thresh
    maprange
    interpolate
    norm
    mapcolor
    mapcolors
    interval_overlap
    cartesian_product
    between
);

# Recursively flattens an array (nested array of arrays) into one long array
# See also L<Moose::Autobox::Array::flatten_deep> for OO interface
sub flatten {
    my @a;
    foreach (@_) {
        push @a, (ref($_) eq 'ARRAY') ? flatten(@$_) : $_;
    }
    @a = map { ref($_) =~ /^Math::Big/ ? $_->numify : $_ } @a;

    return wantarray ? @a : \@a;
}

sub sum {
    my @a = grep {defined} flatten @_;
    return unless @a;
    return List::Util::sum @a;
}

sub min {
    return List::Util::min grep {defined} flatten @_;
}

sub max {
    return List::Util::max grep {defined} flatten @_;
}

sub uniq {
    my @a = List::MoreUtils::uniq flatten @_;
    return wantarray ? @a : \@a;
}

# Numeric sort (See also Sort::Key::nsort() )
sub nsort {
    my @a = sort { $a <=> $b } flatten @_;
    return wantarray ? @a : \@a;
}

sub swap (\$\$) {
    my ($x, $y) = @_;
    my $c = $$x;
    $$x = $$y;
    $$y = $c;
}

# Permutes a copy, not in-place
sub permute {
    my @a = grep {defined} flatten @_;
    for (0 .. $#a) {
        swap($a[$_], $a[ rand(@a) ]);
    }
    return wantarray ? @a : \@a;
}

# http://www.perlmonks.org/?node_id=453733
# http://docstore.mik.ua/orelly/perl/prog3/ch06_04.htm
sub argmax(&@) {
    return unless @_ > 1;
    my $codeblock = shift;
    my $elem      = shift;
    $_ = $elem;
    my $max = &$codeblock;
    for (@_) {
        my $val = &$codeblock;
        ($max, $elem) = ($val, $_) if $val > $max;
    }
    return wantarray ? ($elem, $max) : $elem;
}

# http://www.perlmonks.org/?node_id=453733
# http://docstore.mik.ua/orelly/perl/prog3/ch06_04.htm
sub argmin(&@) {
    return unless @_ > 1;
    my $codeblock = shift;
    my $elem      = shift;
    $_ = $elem;
    my $min = &$codeblock;
    for (@_) {
        my $val = &$codeblock;
        ($min, $elem) = ($val, $_) if $val < $min;
    }
    return wantarray ? ($elem, $min) : $elem;
}

# Average of a list
sub mean {
    my @a = grep {defined} flatten @_;
    return unless @a;
    return sum(@a) / @a;
}
sub avg     { return mean @_ }
sub average { return mean @_ }

sub wtavg {
    my ($a, $weights) = @_;
    return dotproduct($a, $weights) / sum($weights);
}

sub dotproduct {
    my ($a, $b) = @_;
    return unless $a->length == $b->length;
    my $sum = 0;
    for (my $i = 0; $i < $a->length; $i++) {
        $sum += $a->[$i] * $b->[$i];
    }
    return $sum;
}

sub median {
    my @a = grep {defined} flatten @_;
    return unless @a;
    @a = sort { $a <=> $b } @a;
    my $n = $#a;
    if (@a % 2) {
        return $a[ $n / 2 ];
    }
    else {
        return ($a[ $n / 2 ] + $a[ $n / 2 + 1 ]) / 2.0;
    }
}

# Variance of a list
sub variance {
    my @a = grep {defined} flatten @_;
    return 0 unless @a > 1;
    my $avg = avg @a;
    my $sumsqdiff = sum map { ($_ - $avg)**2 } @a;

    # One degree of freedom, subtract 1
    return $sumsqdiff / (@a - 1);
}

# Stddev of a list
sub stddev {
    return sqrt variance @_;
}

# Creates a sequence of numbers (similar to in R)
sub sequence {
    my ($start, $end, $inc) = @_;
    return $start .. $end unless $inc && $inc > 1;
    my @a;
    for (my $i = $start; $i <= $end; $i += $inc) {
        push @a, $i;
    }
    return wantarray ? @a : \@a;
}

# Input an array of arrays, i.e. intersection([1..5],[3..7],...)
# Works with any numbers of arrays
# Objects are compared with string equality,
# but objects, rather than strings, are returned, if given as input
sub intersection {

    # Number of input arrays
    my $n = @_;

    # Number of occurances of each thing
    my %counts;

    # References to the original objects (otherwise they'd just be stringified)
    my %things;

    # First uniq each array, otherwise counting will not work. We assume that N
    # occurances of an object means that it occurred once in each array.
    my @uniq = map { scalar(uniq($_)) } @_;

    # Count occurances of each thing, over all arrays
    foreach my $a (@uniq) {
        $counts{$_}++ for @$a;

        # Overwrites any string-equal objects previously seen
        $things{$_} = $_ for @$a;
    }

    # Which elements exist in each input array (i.e. occur exactly N times)
    my @common = grep { $counts{$_} == $n } keys %counts;

    # Get the corresponding values (i.e. the non-strigified version of objects)
    my @a = map { $things{$_} } @common;
    return wantarray ? @a : \@a;

}    # intersection

# Each element in the list(s) will be represented just once, unsorted
sub union {
    my @a = uniq(flatten(@_));
    return wantarray ? @a : \@a;
}

# All one-directional paired combinations of a list:
# pairs(a,b,c) => ([a,b],[a,c],[b,c])
# cf. List::Pairwise (consider submitting a patch)
sub pairs {

    # For all indices 0 through $#_ of the @_ array:
    #   And then for all indices $_+1 through $#_ of the @_ array:
    #     Makes a pair, returning an array of 2-tuples
    return map {
        my $a = $_[$_];
        map { [ $a, $_[$_] ] } ($_ + 1) .. $#_
    } 0 .. $#_;
}

# All pairs from two separate lists, each pair contains one element from each
sub pairs2 {
    my ($list1, $list2, $noself) = @_;
    return unless @$list1 && @$list2;
    my @pairs;
    foreach my $l1 (@$list1) {
        foreach my $l2 (@$list2) {
            next if $noself && $l1 eq $l2;
            push @pairs, [ $l1, $l2 ];
        }
    }
    return @pairs;
}

# longest_common_prefix
sub lcp {
    @_ = flatten @_;

    # Start with the shortest prefix
    my @strings = sort { length $a <=> length $b } @_;
    my $prefix = shift @strings;
    for (@strings) {

        # For each other string, shorten prefix, until it matches
        # The \Q is necessary to quotemeta() any non-alphanum chars in $prefix
        chop $prefix while (!/^\Q$prefix/);
    }
    return $prefix;
}

=head2 reorder

 Title   : reorder
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :

The Perl sort() is fine for sorting things alphabeticall/numerically.

This is for sorting objects in a pre-defined order, based optionally on some
attribute, which you define by a subroutine that you can pass in.

Takes:
$objects - an ArrayRef of objects, in any order
$ordering - an ArrayRef defining the desired order
$code - a subroutine to apply to the objects, to get the attributes to be sorted

Otherwise, standard Perl stringification is used on the objects, i.e. "$obj"
$ordering - an arrayref of keys (as strings) in the desired order
  If no ordering given, sorts lexically
E.g.: 
NB: duplicate $objects (having the same key) are removed

E.g.:

 my $orderedpts = reorder($points, [ qw/red blue green/ ], sub { $_->color() });

where $points in an ArrayRef of objects, on which ->color() can be called,
returning one of 'red', 'blue', or 'green' in this case.

TODO BUG: will sqaush entries when keys map to non-unique values.

Better solution: Sort::Key

=cut

sub reorder_broken ($;$&) {
    my ($objects, $ordering, $code) = @_;

    # First put the objects into a dictionary, after applying code
    $code ||= sub {"$_"};
    my %dict = map { $code->($_) => $_ } @$objects;

    # Sort lexically by default
    $ordering ||= [ sort keys %dict ];

    # Sorted array (of values) based on given ordering (of keys)
    my @sorted = map { $dict{$_} } @$ordering;
    return wantarray ? @sorted : \@sorted;
}    # reorder

sub maprange {
    my ($val, $min1, $max1, $min2, $max2) = @_;
    return $val unless $max1 - $min1;
    return interpolate(norm($val, $min1, $max1), $min2, $max2);
}

# Also for inverted (large to small) ranges
sub interpolate {
    my ($norm, $min, $max) = @_;
    return $min + ($max - $min) * $norm;
}

# Where is a value, withing a range, as a decimal
# Also for inverted (large to small) ranges
sub norm {
    my ($val, $min, $max) = @_;
    return ($val - $min) / ($max - $min);
}

# Map a numeric value to a "value" of a single color:
# i.e. given: red or green or blue, determine how red, how green, or how blue
# color_min and color_max should be hex, with or without preceeding '0x'
# Returns hex, without the preceeding '0x'
sub mapcolor {
    my ($val, $min1, $max1, $color_min, $color_max) = @_;
    $val ||= 0;
    $color_min = hex($color_min);
    $color_max = hex($color_max);
    my $color = maprange($val, $min1, $max1, $color_min, $color_max);
    $color = sprintf("%02x", $color);
    $color =~ s/^0x//;
    return $color;
}

# Map into a range of RGB values (I.e. a gradient)
# color_min and color_max should be full RGB colors, e.g. '#3b5ab9'
# Reversed (large to small) ranges are accepted
# E.g. scale a score in the range [0:10] to a gradient in red to green:
# $the_color_of_x = mapcolors($the_value_of_x, 0, 10, '#ff0000', '#00ff00');
sub mapcolors {
    my ($val, $min1, $max1, $color_min, $color_max) = @_;
    my ($rmin, $gmin, $bmin) = $color_min =~ /^#(..)(..)(..)$/;
    my ($rmax, $gmax, $bmax) = $color_max =~ /^#(..)(..)(..)$/;

    my $red   = mapcolor($val, $min1, $max1, $rmin, $rmax);
    my $green = mapcolor($val, $min1, $max1, $gmin, $gmax);
    my $blue  = mapcolor($val, $min1, $max1, $bmin, $bmax);

    return '#' . $red . $green . $blue;
}

# Overlap extent of two intervals
# How much of first interval is covered by second interval
# Given: start1, end1, start2, end2
sub interval_overlap {
    my ($a0, $an, $b0, $bn) = @_;
    my $alen = $an - $a0;
    my $blen = $bn - $b0;

    # Smallest end minus largest start
    my $overlap = min($an, $bn) - max($a0, $b0);
    $overlap = 0 if $overlap < 0;

    # Fration of coverage
    my $afrac = 1.0 * $overlap / $alen;
    my $bfrac = 1.0 * $overlap / $blen;
    return wantarray ? ($afrac, $bfrac) : $afrac;
}

sub between {
    my ($x, $min, $max) = @_;
    return defined($x) && $x >= $min && $x < $max;
}

1;
__END__


