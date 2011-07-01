#!/usr/bin/env perl

=head1 NAME



=head1 SYNOPSIS




=head1 DESCRIPTION



=head1 SEE ALSO


=cut



package SBG::Eval::Target;
use Moose;
with 'SBG::Role::Writable';
with 'SBG::Role::Storable';
with 'SBG::Role::Clonable';
with 'SBG::Role::Scorable';


has 'label' => (
    is => 'rw',
    isa => 'Str',
    );

has 'complex' => (
    is => 'rw',
    isa => 'SBG::Complex',
    handles => [qw/size count/],
    );

has 'models' => (
    isa => 'HashRef[SBG::Eval::Model]',
    is => 'ro',
    lazy => 1,
    default => sub { { } },
    trigger => sub {
        my $self=shift;
        $self->scores->put('nmodels',$self->models->length);
        $self->clear_best;
    }
    );


# Best model yet evaluated
has 'best' => (
    isa => 'SBG::Eval::Model',
    is => 'rw',
    lazy_build => 1,
    );
sub _build_best {
    my ($self) = @_;

    # TODO which field to sort on, and ascending or descending
    my $field = 'medsc';
    my $order = 'asc';
    # NB changing the field or order should clear 'best'

    my $values = $self->models->values;
    if ($order =~ /^asc/i) {
        $values = $values->sort(sub{$a->$field <=> $b->$field});
    } else {
        $values = $values->sort(sub{$b->$field <=> $a->$field});
    }    
    return $values->head;
}



=head2 evaluate

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub evaluate {
    my ($self, $model) = @_;
    
    my $ev = SBG::Eval::Model->new(target=>$self,complex->$model);

#     $self->models->put($label, $ev);

    return $ev;

}


###############################################################################
__PACKAGE__->meta->make_immutable;
no Moose;
1;

