#!/usr/bin/env perl

package SBG::List;
use base qw(Exporter);

our @EXPORT = qw(
nsort
);

our @EXPORT_OK = qw(
argmax
argmin
mean
avg
variance
stddev
sequence
lcp
nsort
intersection
union
pairs
retrieve_files
rearrange
reorder
thresh
flatten
);

use List::Util qw(sum);
use List::MoreUtils qw(uniq);
use Storable;

# TODO find stdev mean

################################################################################


# Average of a list
sub mean {
    return unless @_;
    return sum(@_) / @_;
}
sub avg { return mean @_ }

# Variance of a list 
sub variance {
    my @list = flatten(@_);
    return 0 unless @list > 1;
    my $sum = 0;
    my $avg = avg(\@list);
    my $sumsqdiff = sum map { ($_ - $avg)**2 } @list;
    # One degree of freedom
    return $sumsqdiff / (@list - 1);
}

# Stddev of a list
sub stddev {
    return sqrt variance @_;
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


# Get all the objects from all the Stor'ed arrays in all the given files
# use Storable
sub retrieve_files {
    my @files = @_;
    my @allobjs;
    foreach my $file (@files) {
        # Might be an array, expand/flatten it.
        push @allobjs, flatten(retrieve $file);
    }
    return @allobjs;
}


# One way to support named function parameters. E.g.:
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


################################################################################
=head2 reorder

 Title   : reorder
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :

The Perl sort() is fine for sorting things alphabeticall/numerically.
  This is for sorting objects in a pre-defined order, based on some attribute
Sorts objects, given a pre-defined ordering.
Takes:
$objects - an arrayref of objects, in any order
$accessor - the name of an accessor function to call on each object, like:
    $_->$accessor()
Otherwise, standard Perl stringification is used on the objects, i.e. "$obj"
$ordering - an arrayref of keys (as strings) in the desired order
  If no ordering given, sorts lexically
E.g.: 
NB: duplicate $objects (having the same key) are removed

=cut
sub reorder {
    my ($objects, $ordering, $accessor) = @_;
    # First put the objects into a dictionary, indexed by $accessor
    my %dict;
    if ($accessor) {
        %dict = map { $_->$accessor() => $_ } @$objects;
    } else {
        %dict = map { $_ => $_ } @$objects;
    }
    # Sort lexically by default
    $ordering ||= [ sort keys %dict ];
#     $logger->trace("order by: @$ordering");
#     $logger->trace("with accessor: $accessor") if $accessor;
    # Sorted array (of values) based on given ordering (of keys)
    my @sorted = map { $dict{$_} } @$ordering;
#     $logger->debug("reorder'ed: @sorted");
    return \@sorted;
} # reorder


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
    my @objs = map { $things{$_} } @common;
    return @objs;
}


sub union {
    return uniq(flatten(@_));
}


# All one-directional combinations of two lists:
# pairs(a,b,c) => ([a,b],[a,c],[b,c])
sub pairs {
    # For all indices 0 through $#_ of the @_ array:
    #   And then for all indices $_+1 through $#_ of the @_ array:
    #     Makes a pair, returning an array of 2-tuples
    return map { my $a=$_[$_]; map { [ $a , $_[$_] ]} ($_+1)..$#_ } 0..$#_
}    


# Recursively flattens an array (nested array of arrays) into one long array
sub flatten { 
    my @a;
    foreach (@_) {
        push @a, (ref($_) eq 'ARRAY') ? flatten(@$_) : $_;
    }
    return @a;
}


# longest_common_prefix 
sub lcp {
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


################################################################################
1;
__END__


