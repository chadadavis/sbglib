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
    '""' => 'asstring',
    'cmp' => 'compare',
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

sub asstring {
    my ($self) = @_;
    my $class = ref($self) || $self;
    return $self->primary_id;
}

sub compare {
    my ($a, $b) = @_;
    return $a->primary_id cmp $b->primary_id;
}


###############################################################################

1;

__END__
