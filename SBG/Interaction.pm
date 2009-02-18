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
extends 'Bio::Network::Interaction';
with 'SBG::Storable';

use SBG::HashFields;

use overload (
    '""' => '_asstring',
    'cmp' => '_compare',
    );



################################################################################
# Accessors


################################################################################
=head2 template

 Function: Sets the L<SBG::Domain> used to model one of the L<SBG::Nodes>
 Example : $interaction->template($node1, $dom1);
 Returns : The L<SBG::Domain> used to model $node for this L<SBG::Interaction>
 Args    : L<SBG::Node>
           optional L<SBG::Domain> 

my ($node1, $node2) = $interaction->nodes;
$interaction->template($node1,$dom1);
$interaction->template($node2,$dom2);

=cut
hashfield 'template';


################################################################################
=head2 score

 Function:
 Example : $ix->score('e-value', 3e-3);
 Returns :
 Args    :

keys: zscore pval irmsd
=cut
hashfield 'score';



################################################################################
=head2 new

 Function: 
 Example : 
 Returns : A L<SBG::Interaction>, subclassed from L<Bio::Network::Interaction>
 Args    : 

Delegates to L<Bio::Network::Interaction>

=cut
sub new () {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    bless $self, $class;
    return $self;
}


################################################################################
=head2 names

 Title   : names
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut
sub names {
   my ($self,@args) = @_;
   return sort keys %{$self->{template}};
}


################################################################################
=head2 ascsv

 Function: Return tab-separated line of components and their templates 
 Example : 
 Returns : 
 Args    : 

E.g.:

RRP41 RRP42  2br2 { A 108 _ to A 148 _ } 2br2 { D 108 _ to D 148 _ } 

See L<SBG::NetworkIO>

=cut
sub ascsv {
    my ($self,) = @_;
    my ($node1, $node2) = sort $self->nodes;
    my ($dom1, $dom2) = map { $self->template($_) } ($node1, $node2);
    my ($pdb1, $pdb2) = map { $_->pdbid } ($dom1, $dom2);
    my ($descr1, $descr2) = map { $_->descriptor } ($dom1, $dom2);
    return "$node1\t$node2\t$pdb1 { $descr1 } $pdb2 { $descr2 }";
}


sub _asstring {
    my ($self) = @_;
    return $self->primary_id;
}

sub _compare {
    my ($a, $b) = @_;
    return $a->primary_id cmp $b->primary_id;
}


###############################################################################
__PACKAGE__->meta->make_immutable;
1;

__END__


