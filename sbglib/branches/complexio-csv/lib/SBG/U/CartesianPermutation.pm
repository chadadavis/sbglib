#!/usr/bin/env perl

=head1 NAME

SBG::U::CartesianPermutation - Cartesian product of sets of permutations

=head1 SYNOPSIS

 use SBG::U::CartesianPermutation;
 my $pm123 = Algorithm::Combinatorics::variations([1,2,3]);
 my $pm45 = Algorithm::Combinatorics::variations([4,5]);  
 my $pm6 = Algorithm::Combinatorics::variations([6]);  

 my $pm = SBG::U::CartesianPermutation->new([$pm123, $pm45, $pm6]);

 while (my $thing = $pm->next) {
    print "@$thing\n"; 
 }

prints:
 1 2 3 4 5 6
 1 2 3 5 4 6
 1 3 2 4 5 6
 ...

Limit to a nPk permutation by including an array of sizes:

  my $pm = SBG::U::CartesianPermutation->new([$pm123, $pm45, $pm6], [2, 1, 1]);


# This would result in: (2 elems from first group, 1 from 2nd, 1 from 3rd)

 1 2 4 6
 1 2 5 6 
 1 3 4 6
 2 1 4 6
 2 1 5 6
 2 3 4 6
 2 3 5 6
 ...

=head1 DESCRIPTION

Works like L<Set::Product>, which is also a generator, except that this module
also accepts generators (e.g. from L<Algorithm::Combinatorics>) rather than
lists.

The generator objects provided must implement the method B<next()>


=head1 SEE ALSO

L<Set::CrossProduct> , L<Algorithm::Combinatorics>

Both of these can return an iterator, but L<Set::CrossProduct> does not accept
iterators as input, hence this module.

=cut


package SBG::U::CartesianPermutation;
use Moose;
use Moose::Autobox;

use Log::Any qw/$log/;
use Algorithm::Combinatorics qw/variations/;


has 'classes' => (
    isa => 'ArrayRef',
    is => 'rw',
    required => 1,
    );


# Number of classes
has 'length' => (
    isa => 'Int',
    is => 'rw',
    default => sub { shift->classes->length },
    );


# Per-class length
# Defaults to full size of each class
has 'kclass' => (
    isa => 'ArrayRef',
    is => 'rw',
    lazy_build => 1,
    );
sub _build_kclass {
    my ($self) = @_;
    return $self->classes->map(sub{$_->length})
}


# One iterator per class, to generate all permutions of each class
has 'iterators' => (
    isa => 'ArrayRef',
    is => 'rw',
    lazy_build => 1,
    init_arg => undef,
    );
sub _build_iterators {
    my ($self) = @_;

    my $n = $self->length - 1;
    # One permutation iterator per class
    my @perms = map { 
        scalar variations($self->classes->[$_], $self->kclass->[$_]) 
    } 0..$n ;
    return \@perms
}


# The (saved) current value of the iterator for each class
has 'current' => (
    isa => 'ArrayRef',
    is => 'rw',
    default => sub { [] },
    );


# Reset the permuation generator for a given class and return the iterator
sub _reset_i {
    my ($self, $i) = @_;
    $self->current->[$i] = undef;
    return $self->iterators->[$i] = 
        scalar variations($self->classes->[$i], $self->kclass->[$i]);
}


# Set the default parameter for object construction to 'classes'
# http://search.cpan.org/~flora/Moose-1.05/lib/Moose/Manual/Construction.pod
around 'BUILDARGS' => sub {
    my $orig = shift;
    my $class = shift;

    if ( @_ == 1) {
        return $class->$orig('classes' => $_[0]);
    }
    else {
        return $class->$orig(@_);
    }
};



=head2 next

 Function: 
 Example : 
 Returns : 
 Args    : 



=cut
sub next {
    my ($self, $i) = @_;
    # Start at level 0
    $i ||= 0;
    # All lists have been appended already?
    return if $i >= $self->length;

    my $rest = $self->next($i+1);

    # If we didn't exhaust the rest yet, don't interate
    my $next;
    if ($rest) {
        $self->current->[$i] ||= $self->iterators->[$i]->next;
        $next = $self->current->[$i];
    } else {
        $next = $self->current->[$i] = $self->iterators->[$i]->next;
        unless ($next) {
            $self->_reset_i($i);
            return;
        }
        # Re-fetch the rest, which will reinitialize them
        $rest = $self->next($i+1);
    }
    return [ $next ] unless $rest;
    return [ $next, @$rest ];
}


# Product of the number of permutations of each iterator
sub cardinality {
    my ($self) = @_;
    my $prod = 1;
    foreach my $i (0..$self->length - 1) {
        # How many permutations possible for this iterator
        my $n = $self->classes->[$i]->length;
        my $k = $self->kclass->[$i];
        my $nPk = nPk($n, $k);
        $prod *= $nPk;
    }
    return $prod;
}


# How many permutations are we expecting for single iterator
# n!/(n-k)!
sub nPk { 
    my ($n, $k) = @_;
    return factorial($n) / factorial($n-$k);
}


sub factorial {
    my ($n) = @_;
  
    my $f;
    for($f = 1 ; $n > 0 ; $n--){
        $f *= $n
    }

    return $f;
}


__PACKAGE__->meta->make_immutable;
no Moose;
1;

