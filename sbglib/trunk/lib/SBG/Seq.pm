#!/usr/bin/env perl

=head1 NAME

SBG::Seq - Additions to Bioperl's L<Bio::Seq>

=head1 SYNOPSIS

 use SBG::Seq;


=head1 DESCRIPTION

Simple extensions to L<Bio::Seq> to define stringificition, string equality and
string comparison, all based on the B<accession_number> field.

=head2 SEE ALSO

L<Bio::Seq>

=cut

################################################################################

# overload stringify of external package
# package Bio::Seq;
# use overload ('""'=>'stringify');
# sub stringify { (shift)->display_id }


package SBG::Seq;
use Moose;
extends qw/Bio::Seq Moose::Object/;

with qw/
SBG::Role::Storable
/;

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
    return $self->accession_number;
}


sub _compare {
    my ($a, $b) = @_;
    return $a->accession_number cmp $b->accession_number;
}


###############################################################################
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
no Moose;
1;


