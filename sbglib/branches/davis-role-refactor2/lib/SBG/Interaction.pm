#!/usr/bin/env perl

=head1 NAME

SBG::Interaction - Additions to Bioperl's L<Bio::Network::Interaction>

=head1 SYNOPSIS

 use SBG::Interaction;


=head1 DESCRIPTION

Additions for stringification and string comparison. Based on B<primary_id>
field of L<Bio::Network::Interaction> .

=head1 SEE ALSO

L<Bio::Network::Interaction> , L<SBG::Node>

=cut

################################################################################

package SBG::Interaction;
use Moose;

# Explicitly extend Moose::Object when inheriting from non-Moose class
# Order is relevant here, first class listed provides 'new()' method
extends qw/Bio::Network::Interaction Moose::Object/;

with qw/
SBG::Role::Storable
SBG::Role::Dumpable
SBG::Role::Clonable
SBG::Role::Scorable
/;

use overload (
    '""' => 'stringify',
    fallback => 1,
    );


use MooseX::AttributeHelpers;
use SBG::Model;


################################################################################
=head2 models

 Function: Sets the L<SBG::Model> used to model one of the L<SBG::Node>s
 Example : my $model = new SBG::Model(query=>$myseq, subject=>$mydomain);
           $interaction->set($mynode, $model);
           my $model = $interaction->get($node1);
           my ($seq, $domain) = ($model->query, $model->subject);
 Returns : The L<SBG::Model> used to model a given L<SBG::Node>
 Args    : L<SBG::Node>
           L<SBG::Model> 

my ($node1, $node2) = $interaction->nodes;
my $model1 = new SBG::Model(query=>$node1->proteins, $template_domain1);
$interaction->set($node1,$model1);
my $model1 = $interaction->get($node1);

=cut
has 'models' => (
    metaclass => 'Collection::Hash',
    isa => 'HashRef[SBG::Model]',
    is => 'ro',
    lazy => 1,
    default => sub { { } },
    provides => {
        'count' => 'count',
        'get' => 'get',
        'set' => 'set',
        'delete' => 'delete',
        'keys' => 'keys',
        'values' => 'values',
    },
    );


################################################################################
=head2 new

 Function: 
 Example : 
 Returns : A L<SBG::Interaction>, subclassed from L<Bio::Network::Interaction>
 Args    : 

Delegates to L<Bio::Network::Interaction>

=cut
override 'new' => sub {
    my ($class, @ops) = @_;
    
    # This creates a Bio::Network::Interaction
    my $obj = $class->SUPER::new(@ops);

    # This appends the Bio::Network:: with goodies from Moose::Object
    # __INSTANCE__ place-holder fulfilled by $obj (Bio::Network::Interaction)
    $obj = $class->meta->new_object(__INSTANCE__ => $obj);

    # bless'ing should be automatic!
    bless $obj, $class;
    return $obj;
};


sub stringify {
    my ($self) = @_;
    return $self->primary_id;
}


###############################################################################
__PACKAGE__->meta->make_immutable(inline_constructor=>0);
no Moose;
1;


