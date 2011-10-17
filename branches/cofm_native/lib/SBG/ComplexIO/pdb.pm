#!/usr/bin/env perl

=head1 NAME

SBG::ComplexIO::pdb - 

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::DomainIO::stamp> , L<SBG::Complex>

=cut

package SBG::ComplexIO::pdb;
use Moose;

with 'SBG::IOI';

use Carp;
use Log::Any qw/$log/;
use Moose::Autobox;

use SBG::DomainIO::pdb;
use SBG::ComplexIO::report;

=head2 write

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut

sub write {
    my ($self, $complex) = @_;
    return unless defined $complex;
    $log->debug("complex: ", $complex);
    my $fh = $self->fh or return;
    $log->debug("file: ", $self->file);

    my $report;
    my $reportio = SBG::ComplexIO::report->new(string => \$report);
    $reportio->write($complex);
    $reportio->close;

    # Prepend a comment
    $report =~ s/^/REMARK /gm;
    print $fh $report;

    # Just delegate all domains in the complex to DomainIO::stamp
    my $domio = SBG::DomainIO::pdb->new(fh => $fh);
    $domio->write($complex->domains->flatten);

    return $self;
}    # write

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

    # TODO consider multi-model files
    warn "Not implemented";
    return;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
