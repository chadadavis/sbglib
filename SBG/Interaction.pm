#!/usr/bin/env perl

=head1 NAME

SBG::Interaction - Additions to Bioperl's L<Bio::Network::Interaction>

=head1 SYNOPSIS

 use SBG::Interaction;


=head1 DESCRIPTION

Additions for stringification and string comparison. Based on B<primary_id>
field of L<Bio::Network::Interaction> .

=head1 SEE ALSO

L<Bio::Network::Interaction> , L<Bio::Network::Node> , L<SBG::Node>

=cut

################################################################################

package SBG::Interaction;
use SBG::Root -base, -XXX;
use base qw(Bio::Network::Interaction);

use overload (
    '""' => '_asstring',
    'cmp' => '_compare',
    );


################################################################################

sub new () {
    my $class = shift;
    # Delegate to parent class
    my $self = new Bio::Network::Interaction(@_);
    # And add our ISA spec
    bless $self, $class;
    # Is now both a Bio::Network::Interaction and an SBG::Interaction
    return $self;
}

sub _asstring {
    my ($self) = @_;
    my $class = ref($self) || $self;
    return $self->primary_id;
}

sub _compare {
    my ($a, $b) = @_;
    return $a->primary_id cmp $b->primary_id;
}

# Spits out the same interaction format that we read in 
# See L<SBG::NetworkIO>
sub regurgitate {
    my $self = shift;
    my ($node1, $node2) = sort $self->nodes;
    my ($dom1, $dom2) = map { $self->template($_) } ($node1, $node2);
    my ($pdb1, $pdb2) = map { $_->pdbid } ($dom1, $dom2);
    my ($descr1, $descr2) = map { $_->descriptor } ($dom1, $dom2);
    return "$node1\t$node2\t$pdb1 { $descr1 } $pdb2 { $descr2 }";
}

################################################################################
=head2 template

 Title   : template
 Usage   : $interaction->template($node1) = $dom1;
 Function: Sets the L<SBG::Domain> used to model one of the L<SBG::Nodes>
 Example : (see below)
 Returns : 
 Args    : L<SBG::Node>

my ($node1, $node2) = $interaction->nodes;
$interaction->template($node1) = $dom1;
$interaction->template($node2) = $dom2;



# Given a component label/accession as key, returns the L<SBG::Domain> used to
# model it in this interaction.
field 'template' => {};

The component L<SBG::Domain> objects collected in this Assembly.  NB These also
contain centres-of-mass as well as Transform's

The return value of this method can be assigned to, e.g.:

 $assem->template('mylabel') = $domainobject;

NB Spiffy doesn't magically create $self here, probably due to the attribute
=cut
sub template : lvalue {
    my ($self,$key) = @_;
    $self->{template} ||= {};
    # Do not use 'return' with 'lvalue'
    $self->{template}{$key};
} # template


###############################################################################

1;

__END__
