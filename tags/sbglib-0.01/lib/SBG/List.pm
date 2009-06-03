#!/usr/bin/env perl

=head1 NAME

SBG::List - Utilities on Arrays

=head1 SYNOPSIS

 use SBG::List;

or

use Moose::Autobox;
use autobox ARRAY => 'SBG::List';


=head1 DESCRIPTION

TODO explain how this works/conflicts with Moose::Autobox

=head1 SEE ALSO

L<List::Utils> , L<List::MoreUtils>

=cut

package SBG::List;
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
variance
stddev
sequence
lcp
intersection
union
pairs
reorder
thresh
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


# Numeric sort
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


sub argmax(&@) {
  return() unless @_ > 1;
  my $block = shift;
  my $index = shift;
  my $max = $block->($index);
  for (@_) {
    my $val = $block->($_);
    ($max, $index) = ($val, $_) if $val > $max;
  }
  return wantarray ? ($index, $max) : $index;
}

sub argmin(&@) {
  return() unless @_ > 1;
  my $block = shift;
  my $index = shift;
  my $min = $block->($index);
  for (@_) {
    my $val = $block->($_);
    ($min, $index) = ($val, $_) if $val < $min;
  }
  return wantarray ? ($index, $min) : $index;
}

# Average of a list
sub mean {
    @_ = flatten @_;
    return unless @_;
    return sum(@_) / @_;
}
sub avg { return mean @_ }

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
    my $n = @_;
    my %counts;
    my %things;
    foreach my $a (@_) {
        $counts{$_}++ for @$a;
        # Overwrites any string-equal objects previously seen
        $things{$_} = $_ for @$a;
    }
    # Which elements exist in each input array
    my @common = grep { $counts{$_} == $n } keys %counts;
    # Get the corresponding values
    my @a = map { $things{$_} } @common;
    return wantarray ? @a : \@a;
}


# Each element in the list(s) will be represented just once, unsorted
sub union {
    my @a = uniq(flatten(@_));
    return wantarray ? @a : \@a;
}


# All one-directional combinations of two lists:
# pairs(a,b,c) => ([a,b],[a,c],[b,c])
sub pairs {
    # For all indices 0 through $#_ of the @_ array:
    #   And then for all indices $_+1 through $#_ of the @_ array:
    #     Makes a pair, returning an array of 2-tuples
    return map { my $a=$_[$_]; map { [ $a , $_[$_] ]} ($_+1)..$#_ } 0..$#_
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
$orderine - an ArrayRef defining the desired order
$code - a subroutine to apply to the objects, to get the attributes to be sorted

Otherwise, standard Perl stringification is used on the objects, i.e. "$obj"
$ordering - an arrayref of keys (as strings) in the desired order
  If no ordering given, sorts lexically
E.g.: 
NB: duplicate $objects (having the same key) are removed

=cut
sub reorder ($;$&) {
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


################################################################################
1;
__END__


