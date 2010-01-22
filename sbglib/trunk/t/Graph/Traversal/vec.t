#!/usr/bin/env perl

use Test::More 'no_plan';

#NB 
# Least significant bit on the right
# To get the better scoring templates to be tried together first, sort desc
my @sorted_sedges = qw/great good better ok worse worst/;


# Like ceil() but finds the next power of 2 rather than just the next integer
sub ceilpower2 {
    my $x = shift;
    return 1 unless $x > 0;
    # Number is already a power of 2?
    # Example: 8=>1000, 7=>0111, AND operator sets every bit to 0
    return $x unless $x & ($x-1);
    # Otherwise do ceil(log base2)
    my $r = 1 + int(log($x) / log(2));
    return 2 ** $r;
}

my $nedges = scalar @sorted_sedges;
# vec() requires number of bits to be a power of 2
my $vecsize = ceilpower2 $nedges;
# $vecsize = 32;
# Bit Vector
my $bitvec;
# Set all bit to enabled/on
vec($bitvec, 0, $vecsize) = 2 ** $nedges - 1;

# The following efficiently counts the number of set bits in a bit vector:
#                    $setbits = unpack("%32b*", $selectmask);


sub bitvec_subset {
    my ($bitvec) = @_;
    # Make sure to use 'b' rather than 'B' here, we want to index from the left
    my @bits = split(//, unpack("b*", $bitvec));
    my @enabled = grep { $bits[$_] } (0..$#bits);
    return @enabled;
}


print "array: ", unpack("B*", $bitvec), "\n";
my @names = @sorted_sedges[bitvec_subset($bitvec)];
print "names : @names\n";

# Except that this doesn't work, because a vec is a packed string, not a number
$bitvec = $bitvec - 1;
# print "array: ", unpack("b*", $bitvec), "\n";
print "array: $bitvec\n";

