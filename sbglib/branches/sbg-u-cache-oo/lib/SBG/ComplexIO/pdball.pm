#!/usr/bin/env perl

=head1 NAME


=head1 SYNOPSIS


=head1 DESCRIPTION

TODO REFACTOR this should simply subclass ComplexIO::pdb


=head1 SEE ALSO


=cut



package SBG::ComplexIO::pdball;
use Moose;

with 'SBG::IOI';

use Carp;

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
    my $fh = $self->fh or return;

    # TODO this needs to be customized to pdball, as it doesn't report all chains
    my $report;
    my $reportio = SBG::ComplexIO::report->new(string=>\$report);
    $reportio->write($complex);
    $reportio->close;
    # Prepend a comment
    $report =~ s/^/REMARK /gm;
    print $fh $report;
    
    # Just delegate all domains in the complex to DomainIO::stamp
    my $domio = SBG::DomainIO::pdb->new(fh=>$fh);
    
    my $models = $complex->all_models;  
    my $domains = $models->map(sub{$_->subject}); 
    $domio->write($domains);

    return $self;
} # write


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
