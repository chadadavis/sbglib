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
interval_overlap
cartesian_product
);


################################################################################

# Recursively flattens an array (nested array of arrays) into one long array
# See also L<Moose::Autobox::Array::flatten_deep> for OO interface
sub flatten { 
    my @a;
    foreach (@_) {
        push @a, (ref($_) eq 'ARRAY') ? flatten(@$_) : $_;
    }
    return wantarray ? @a : \@a;
}

sub sum {
    return List::Util::sum(flatten @_);
}

sub min {
    return List::Util::min flatten @_;
}

sub max {
    return List::Util::max flatten @_;
}

sub uniq { 
    my @a = List::MoreUtils::uniq flatten @_;
    return wantarray ? @a : \@a;
}    


# Numeric sort (See also Sort::Key::nsort() )
sub nsort {
    @_ = flatten @_;
    my @a = sort { $a <=> $b } @_;
    return wantarray ? @a : \@a;
}

sub swap (\$\$) {
    my ($x,$y) = @_;
    my $c = $$x;
    $$x = $$y;
    $$y = $c;
}

# Permutes a copy, not in-place
sub permute {
    @_ = flatten @_;
    for (0..$#_) {
        swap($_[$_], $_[rand(@_)]);
    }
    return wantarray ? @_ : \@_;    
}


# http://www.perlmonks.org/?node_id=453733
# http://docstore.mik.ua/orelly/perl/prog3/ch06_04.htm
sub argmax(&@) {
  return() unless @_ > 1;
  my $codeblock = shift;
  my $elem = shift;
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
  return() unless @_ > 1;
  my $codeblock = shift;
  my $elem = shift;
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
    @_ = flatten @_;
    return unless @_;
    return sum(@_) / @_;
}
sub avg { return mean @_ }
sub average { return mean @_ }


sub median {
    @_ = flatten @_;
    return unless @_;
    @_ = sort { $a <=> $b } @_;
    my $n = $#_;
    if (@_ % 2) {
        return $_[$n/2];
    } else {
        return ($_[$n/2] + $_[$n/2+1]) / 2.0;
    }
}


# Variance of a list 
sub variance {
    @_ = flatten @_;
    return 0 unless @_ > 1;
    my $avg = avg @_;
    my $sumsqdiff = sum map { ($_ - $avg)**2 } @_;
    # One degree of freedom, subtract 1
    return $sumsqdiff / (@_ - 1);
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
    for (my $i = $start; $i <= $end; $i+=$inc) {
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

} # intersection


# Each element in the list(s) will be represented just once, unsorted
sub union {
    my @a = uniq(flatten(@_));
    return wantarray ? @a : \@a;
}


# All one-directional paired combinations of a list:
# pairs(a,b,c) => ([a,b],[a,c],[b,c])
sub pairs {
    # For all indices 0 through $#_ of the @_ array:
    #   And then for all indices $_+1 through $#_ of the @_ array:
    #     Makes a pair, returning an array of 2-tuples
    return map { my $a=$_[$_]; map { [ $a , $_[$_] ]} ($_+1)..$#_ } 0..$#_
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
        chop $prefix while (! /^\Q$prefix/);
    }
    return $prefix;
}



################################################################################
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
    $code ||= sub { "$_" };
    my %dict = map { $code->($_) => $_ } @$objects;
    # Sort lexically by default
    $ordering ||= [ sort keys %dict ];
    # Sorted array (of values) based on given ordering (of keys)
    my @sorted = map { $dict{$_} } @$ordering;
    return wantarray ? @sorted : \@sorted;
} # reorder


sub maprange {
    my ($val, $min1, $max1, $min2, $max2) = @_;
    return $val unless $max1 - $min1;
    return interpolate( norm($val, $min1, $max1), $min2, $max2);
}

sub interpolate {
    my ($norm, $min, $max) = @_;
    return $min + ($max - $min) * $norm;
}

sub norm {
    my ($val, $min, $max) = @_;
    return ($val - $min) / ($max - $min);
}


# Overlap extent of two intervals
# How much of first interval is covered by second interval
# Given: start1, end1, start2, end2
sub interval_overlap {
    my ($a0, $an, $b0, $bn) = @_;
    my $alen = $an-$a0;
    my $blen = $bn-$b0;

    # Smallest end minus largest start
    my $overlap = min($an, $bn) - max($a0, $b0);
    $overlap = 0 if $overlap < 0;
    # Fration of coverage
    my $afrac = 1.0 * $overlap / $alen;
    my $bfrac = 1.0 * $overlap / $blen;
    return wantarray ? ($afrac, $bfrac) : $afrac;
}


# Cartesian cross product of an array of arrays
# http://stackoverflow.com/questions/215908/whats-a-good-non-recursive-algorithm-to-calculate-a-cartesian-product
sub cartesian_product {
  my @input = @_;
  my @ret = @{ shift @input };

  for my $a2 (@input) {
    @ret = map {
      my $v = (ref) ? $_ : [$_];
      map [@$v, $_], @$a2;
    } @ret;
  }
  return @ret;
}


################################################################################
1;
__END__


