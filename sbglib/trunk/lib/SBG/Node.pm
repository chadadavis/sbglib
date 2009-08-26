#!/usr/bin/env perl

=head1 NAME

SBG::Node - Additions to Bioperl's L<Bio::Network::Node>

=head1 SYNOPSIS

 use SBG::Node;


=head1 DESCRIPTION

A node in a protein interaction network (L<Bio::Network::ProteinNet>)

Derived from L<Bio::Network::Node> . It is extended simply to add some simple
stringification and comparison operators.

=head1 SEE ALSO

L<Bio::Network::Node> , L<SBG::Network>

=cut

################################################################################

package SBG::Node;
use Moose;
extends qw/Bio::Network::Node Moose::Object/;
with 'SBG::Role::Storable';

use overload (
    '""' => 'stringify',
    'cmp' => '_compare',
    fallback => 1,
    );



################################################################################
=head2 new

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
override 'new' => sub {
    my ($class, @ops) = @_;
    
    my $obj = $class->SUPER::new(@ops);

    # This appends the object with goodies from Moose::Object
    # __INSTANCE__ place-holder fulfilled by $obj 
    $obj = $class->meta->new_object(__INSTANCE__ => $obj);

    # bless'ing should be automatic!
    bless $obj, $class;
    return $obj;
};


sub stringify {
    my ($self) = @_;
    return join(",", $self->proteins);
} # _asstring


sub _compare {
    my ($a, $b) = @_;

    # Assume each Node holds just one protein
    # Need to stringify here, otherwise it's recursive
    return "$a" cmp "$b";
}


###############################################################################
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
no Moose;
1;

