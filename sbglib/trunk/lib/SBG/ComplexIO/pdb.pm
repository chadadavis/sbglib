#!/usr/bin/env perl

=head1 NAME

SBG::ComplexIO::stamp - 

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::DomainIO::stamp> , L<SBG::Complex>

=cut

################################################################################

package SBG::ComplexIO::pdb;
use Moose;

with 'SBG::IOI';

use Carp;

use Moose::Autobox;


use SBG::DomainIO::pdb;



################################################################################
=head2 write

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub write {
    my ($self, $complex) = @_;
    return unless defined $complex;
    my $fh = $self->fh or return;

    # Just delegate all domains in the complex to DomainIO::stamp
    my $io = SBG::DomainIO::pdb->new(fh=>$fh);
    $io->write($complex->domains->flatten);

    return $self;
} # write


################################################################################
=head2 read

 Title   : 
 Usage   : 
 Function: 
 Example : 
 Returns : 
 Args    : 

=cut
sub read {
    my ($self) = @_;
    warn "Not implemented";
    return;
}


################################################################################
__PACKAGE__->meta->make_immutable;
no Moose;
1;
