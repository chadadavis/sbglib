#!/usr/bin/env perl

=head1 NAME

SBG::Network - Additions to Bioperl's L<Bio::Network::ProteinNet>

=head1 SYNOPSIS

 use SBG::Network;


=head1 DESCRIPTION


=head1 SEE ALSO

L<Bio::Network::Interaction> , L<SBG::Interaction>

=cut

################################################################################

package SBG::Network;
use SBG::Root -base;
use base qw(Bio::Network::ProteinNet);

use overload (
    '""' => '_asstring',
    );


################################################################################

sub new () {
    my $class = shift;
    # Delegate to parent class
    my $self = new Bio::Network::ProteinNet(@_);
    # And add our ISA spec
    bless $self, $class;
    # Is now both a Bio::Network::ProteinNet and an SBG::Network
    return $self;
}

sub _asstring {
    my ($self) = @_;
#     return $self->primary_id;
}


###############################################################################

1;

__END__
