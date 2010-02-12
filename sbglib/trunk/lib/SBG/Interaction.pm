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


with 'SBG::Role::Dumpable';
with 'SBG::Role::Scorable';
with 'SBG::Role::Storable';
with 'SBG::Role::Writable';


use overload (
    '""' => 'stringify',
    '==' => 'equal',
    fallback => 1,
    );


use Moose::Autobox;
use SBG::Model;


################################################################################
=head2 models

 Function: Sets the L<SBG::Model> used to model one of the L<SBG::Node>s
 Example : my $model = new SBG::Model(query=>$myseq, subject=>$mydomain);
           $interaction->put($mynode, $model);
           my $model = $interaction->at($node1);
           my ($seq, $domain) = ($model->query, $model->subject);
 Returns : The L<SBG::Model> used to model a given L<SBG::Node>
 Args    : L<SBG::Node>
           L<SBG::Model> 

my ($node1, $node2) = $interaction->nodes;
my $model1 = new SBG::Model(query=>$node1->proteins, $template_domain1);
$interaction->put($node1,$model1);
my $model1 = $interaction->at($node1);

=cut
has 'models' => (
    isa => 'HashRef[SBG::Model]',
    is => 'ro',
    lazy => 1,
    default => sub { {} },
    );



################################################################################
=head2 set/get/keys

 Function: 
 Example : 
 Returns : 
 Args    : 

Shouldn't be necessary, but neither L<Moose::Autobox> nor
L<MooseX::AttributeHelpers> create attributes that are instances of their own
class. I.e. neither 'handles' nor 'provides' are useful.

=cut
sub set {
    my $self = shift;
    $self->models->put(@_);
    $self->_update_id;
    return $self->models->at(@_);
} # set
sub get {
    my $self = shift;
    return $self->models->at(@_);
}
sub keys {
    my $self = shift;
    return $self->models->keys;
}


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
    # NB @ops is passed here, as this object has Moose attributes
    $obj = $class->meta->new_object(__INSTANCE__ => $obj, @ops);

    # bless'ing should be automatic!
    bless $obj, $class;

    $obj->_update_id;

    return $obj;
};


################################################################################
=head2 irmsd

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub irmsd {
    my ($self, $other) = @_;

    # Define mapping: Assume same keys to models
    my $keys = $self->keys;
    my $selfdoms = $keys->map(sub{$self->get($_)->subject});
    my $otherdoms = $keys->map(sub{$other->get($_)->subject});
    return unless $otherdoms->length == $self->doms->length;

    my $res = SBG::STAMP::irmsd($selfdoms, $otherdoms);
    return $res;

} # irmsd


################################################################################
=head2 domains

 Function: 
 Example : 
 Returns : ArrayRef[SBG::DomainI]
 Args    : 


=cut
sub domains {
    my ($self,$keys) = @_;
    $keys ||= $self->keys;
    return $keys->map(sub{$self->get($_)->subject});

} # domains



################################################################################
=head2 overlap

 Function: 
 Example : 
 Returns : 
 Args    : 

Extent to which two domains in the interaction overlap.

If this is smaller than 0, this might not be an actual interface.

If this is larger than ~50%, this interface might contain clashes

=cut
sub overlap {
    my ($self,) = @_;

    my ($dom1, $dom2) = $self->domains;
    my $overlapfrac = $dom1->overlap($dom2);
    return $overlapfrac;

} # overlap


# TODO DES belongs in DomSetI. 

# NB A Network may contain multiple Interactions that are equal, as long as they
# are connecting different Nodes

sub equal {
    my ($self, $other) = @_;

    # Domains in each Interaction
    my $selfdoms = $self->domains->sort;
    my $otherdoms = $other->domains->sort;
    
    # Componentwise equality, only if all (two) are true
    return all { $selfdoms->[$_] == $otherdoms->[$_] } (0..1);
}


sub stringify {
    my ($self) = @_;
    return $self->primary_id;
}


sub _update_id {
    my ($self) = @_;
    $self->primary_id($self->models->values->join('--'));
}


###############################################################################
__PACKAGE__->meta->make_immutable(inline_constructor=>0);
no Moose;
1;


