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

# Need to use the package first, before adding to it
use Bio::PrimarySeqI;
# overload stringify of external package
package Bio::PrimarySeqI;
use overload ('""'=>'stringify');

# NB cannot use ->primary_id in operator "" because it'd be recursive
sub stringify { my $self=shift(); $self->display_id || $self->accession_number }


package SBG::Seq;
use Moose;
extends qw/Bio::Seq Moose::Object/;

with qw/
SBG::Role::Storable
/;

use overload (
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


###############################################################################
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
no Moose;
1;


