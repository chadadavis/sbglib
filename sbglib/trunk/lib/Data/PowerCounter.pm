#!/usr/bin/env perl

package PowerCounter;
use Moose;
use Moose::Autobox;

# Will permit -- and ++ increment and decrement
use overload 
    '0+' => sub {$_[0]->index},
    '+' => sub {my ($self,$n)=@_; $self->index($self->index+$n)},
    fallback => 1,
    ;


has 'index' => (
    is => 'rw',
    isa => 'Int',
    lazy_build => 1,
    );

sub _build_index {
    my ($self) = @_;
    return 2 ** $self->set->length - 1;
}

has 'set' => (
    is => 'ro',
    isa => 'ArrayRef',
    required => 1
    );


sub BUILDARGS {
    my $class = shift;
    my ($param) = @_;
    
    # Only a single param and it's not a hash ref, it must be the set
    if (@_ == 1 && 'ARRAY' eq ref $param) {
        return { set => $param };
    }
    else {
        return $class->SUPER::BUILDARGS(@_);
    }
}

1;

