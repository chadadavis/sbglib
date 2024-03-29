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

package SBG::Interaction;
use Moose;

# Explicitly extend Moose::Object when inheriting from non-Moose class
# Order is relevant here, first class listed provides 'new()' method
extends qw/Bio::Network::Interaction Moose::Object/;

with qw(
    SBG::Role::Dumpable
    SBG::Role::Scorable
    SBG::Role::Storable
    SBG::Role::Writable
    SBG::Role::Clonable
    SBG::Role::Transformable
);

use overload (
    '""'     => 'stringify',
    '=='     => 'equal',
    fallback => 1,
);

use Moose::Autobox;

# Must load SBG::Seq to get string overload on Bio::PrimarySeqI
use SBG::Seq;
use SBG::Model;
use SBG::U::iRMSD;

=head2 _models

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

has '_models' => (
    isa     => 'HashRef[SBG::Model]',
    is      => 'ro',
    lazy    => 1,
    default => sub { {} },
);

=head2 source

A label representing the source database of this interaction, or interaction
template.

=cut

has 'source' => (
    isa => 'Str',
    is  => 'rw',
);

=head2 id

Unique identifier (within 'source')

=cut

has 'id' => (
    isa => 'Int',
    is  => 'rw',
);

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
    $self->_models->put(@_);
    $self->_update_id;
    return $self->_models->at(@_);
}    # set

sub get {
    my $self = shift;
    return $self->_models->at(@_);
}

sub keys {
    my $self = shift;
    return $self->_models->keys->sort;
}

=head2 new

 Function: 
 Example : 
 Returns : A L<SBG::Interaction>, subclassed from L<Bio::Network::Interaction>
 Args    : 

Delegates to L<Bio::Network::Interaction>

NB it's best not to set any attributes in the construtor, as the parent class
has different semantics. Rather, create the object with an empty constructor and
use the setter methods to set attribute values.

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

=head2 irmsd

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut

sub irmsd {
    my ($self, $other) = @_;

    # Define mapping: Assume same keys to models
    my $keys      = $self->keys;
    my $selfdoms  = $keys->map(sub { $self->get($_)->subject });
    my $otherdoms = $keys->map(sub { $other->get($_)->subject });
    return unless $otherdoms->length == $self->doms->length;

    my $res = SBG::U::iRMSD::irmsd($selfdoms, $otherdoms);
    return $res;

}    # irmsd

=head2 domains

 Function: 
 Example : 
 Returns : ArrayRef[SBG::DomainI]
 Args    : 


=cut

sub domains {
    my ($self, $keys) = @_;
    $keys ||= $self->keys;
    return $keys->map(sub { $self->get($_)->subject });

}    # domains

=head2 domains

 Function: 
 Example : 
 Returns : ArrayRef[SBG::Model]
 Args    : 


=cut

sub models {
    my ($self, $keys) = @_;
    $keys ||= $self->keys;
    return $keys->map(sub { $self->get($_) });

}    # models

=head2 pdbid

 Function: 
 Example : 
 Returns : 
 Args    : 

PDB structure entry code from which this interaction template is derived

=cut

sub pdbid {
    my ($self,) = @_;
    return $self->domains->head->pdbid;
}    # pdbid

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

}    # overlap

# TODO DES belongs in DomSetI.

# NB A Network may contain multiple Interactions that are equal, as long as they
# are connecting different Nodes

sub equal {
    my ($self, $other) = @_;

    # Domains in each Interaction
    my $selfdoms  = $self->domains->sort;
    my $otherdoms = $other->domains->sort;

    # Componentwise equality, only if all (two) are true
    return all { $selfdoms->[$_] == $otherdoms->[$_] } (0 .. 1);
}

=head2 avg_scores

 Function: 
 Example : 
 Returns : 
 Args    : @keys the names of the fields to be averaged, e.g. qw/seqid cover/;

Adds scores to the Interaction object of the form: avg_thing for each 'thing' in
the two models within the Interaction. E.g. if each model in the Interaction has
a seqid of 40% and 60%, respectively, the there will also be a
Interaction->scores->at('avg_seqid') with value 50%.

TODO replace with Scores::reduce($_, 'avg') for @keys

TODO belongs in Role::Scorable

=cut

sub avg_scores {
    my ($self, @keys) = @_;
    return unless @keys;
    my ($s1, $s2) = $self->_models->values->flatten;
    return unless defined $s1 && defined $s2;
    foreach my $key (@keys) {
        next
            unless defined($s1->scores->at($key))
                && defined($s2->scores->at($key));
        my $avg = ($s1->scores->at($key) + $s2->scores->at($key)) / 2.0;
        $self->scores->put("avg_$key", $avg);
    }

}    # avg_scores

sub stringify {
    my ($self) = @_;
    return $self->_models->values->sort->join('--');
}

=head2 transform

 Title   : transform
 Usage   :
 Function: Transforms each component L<SBG::Model> by a given L<PDL> matrix
 Example :
 Returns : 
 Args    : L<PDL> 4x4 homogenous transformation matrix


=cut

sub transform {
    my ($self, $matrix) = @_;
    foreach my $model (@{ $self->models->values }) {
        $model->transform($matrix);
    }
    return $self;
}    # transform

sub _update_id {
    my ($self) = @_;
    $self->primary_id($self->_models->values->sort->join('--'));
}

###############################################################################
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
no Moose;
1;

