#!/usr/bin/env perl

=head1 NAME

SBG::Role::Scorable - 

=head1 SYNOPSIS

with 'SBG::Role::Scorable';

=head1 DESCRIPTION


=head1 SEE ALSO


=cut



package SBG::Role::Scorable;
use Moose::Role;

# Also a functional interface
use base qw/Exporter/;
our @EXPORT_OK = qw/group_scores/;

use Moose::Autobox;

use PDL::Core qw/pdl/;
use PDL::Math; # badmask()

# TODO load these optionally
use List::Util;
use List::MoreUtils;
use Statistics::Lite qw(:all);
 
=head2 scores

 Function: 
 Example : 
 Returns : 
 Args    : 

Note that using lazy_build will cause the default to be reset when accessing the attribute after it has been cleared. In contrast, using 'default' will leave the attribute undefined after a clear.

=cut
has 'scores' => (
    is => 'rw',
    isa => 'HashRef',
    lazy_build => 1, # Re-built (to the default) after a clear
#    default => sub { {} }, # Left undefed after a clear
    clearer => 'clear_scores',
    );
sub _build_scores {
    return {} ;
}



=head2 group_scores

 Function: 
 Example : 
 Returns : 
 Args    : 

Given an array of Scorable objects, extract the 'scores' and populate a
Hashref of ArrayRefs

E.g. converts

 [ { scores=>{size=>10,weight=>3} } , { scores=>{size=>7,weight=>2} } ]

to

 { size=>[10,7], weight=>[3,2] }
 

=cut
sub group_scores {
    my ($array) = @_;
    my $hash = {};
    foreach my $eachhash ($array->flatten) {
        foreach my $key ($eachhash->keys->flatten) {
            $hash->{$key} ||= [];
            $hash->{$key}->push($eachhash->{$key});
        }
    }
    return $hash;
} # group_scores


=head2 score

 Function: 
 Example : 
 Returns : 
 Args    : 


Combined score of all features in a object, using weighting

=cut
has 'score' => (
    is => 'rw',
    isa => 'Num',
    lazy_build => 1,
    clearer => 'clear_score',
    );

sub _build_score {
    my ($self) = @_;
    my $scores = $self->scores();
    # Get the fields to be combined into the score
    my @scores = $scores->slice($self->score_keys)->flatten;
    # Convert any Math::BigInt or Math::BigFloat back to scalar, for PDL
    my @nums = map { ref($_) =~ /^Math::Big/ ? $_->numify : $_ } @scores;
    # Append a '1' for the constant multiplier, after the linear weighting
    push @nums, 1;
    # Switch to PDL format
    my $values = pdl @nums;
    # Set any NaN values to 0
    $values->inplace->badmask(0);
    # Vector product
    my $prod = $self->score_weights() * $values;
    my $sum = $prod->sum;
    return $sum;
}


# The order of these keys must match the weights
# Lexicographic ordering of score keys by default 
has 'score_keys' => (
    is => 'rw',
    isa => 'ArrayRef[Str]',
    lazy => 1,
    clearer => 'clear_score_keys',
    default => sub { shift()->scores->keys()->sort; },
    );
    
        
# Final value is the constant (list is 1 item longer than the keys)
# TODO DES make this is a hash, using the same keys, to avoid out-of-order bugs
has 'score_weights' => (
    is => 'rw',
    isa => 'PDL',
    lazy => 1,
    clearer => 'clear_score_weights',
    default => sub { my $n=shift()->score_keys->length; pdl((1)x$n,0) },
    );


=head2 reduce_scores

 Function: 
 Example : 
 Returns : 
 Args    : 

Given a field in B<scores> named 'length' that contains an ArrayRef of values

 $self->reduce_scores('length', 'median');
 my $med = $self->scores->at('length_median');
 
The field name can be any score that holds an array of values. The method name can be any method defined in (assuming you have these)
=item * L<List::Util>
=item * L<List::MoreUtils>
=item * L<Statistics::Lite>
  

=cut
sub reduce_scores {
    my ($self, $key, $subname) = @_;
    my $values = $self->scores->at($key);
    ref($values) =~ /ARRAY/ or return;
    my $reduced = $subname->(@$values);
    my $rkey = $key . '_' . $subname;
    $rkey =~ s/::/_/g;
    $self->scores->put($rkey, $reduced);
    return $reduced;

} # reduce_scores


no Moose::Role;
1;


