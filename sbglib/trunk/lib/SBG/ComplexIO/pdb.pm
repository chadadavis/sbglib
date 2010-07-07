#!/usr/bin/env perl

=head1 NAME

SBG::ComplexIO::stamp - 

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::DomainIO::stamp> , L<SBG::Complex>

=cut



package SBG::ComplexIO::pdb;
use Moose;

with 'SBG::IOI';

use Carp;

use Moose::Autobox;


use SBG::DomainIO::pdb;




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

    print $fh "REMARK Output from Complex modelling\nREMARK \n";
    
    print $fh "REMARK Interactions\nREMARK \n";
    
    foreach my $iaction ($complex->interactions->values->flatten) {
    	print $fh "REMARK $iaction source=", $iaction->source, ' ';
    	foreach my $score ($iaction->scores->keys->flatten) {
    		print $fh "${score}=", $iaction->scores->at($score), " ";
    	}
    	print "\nREMARK \n";
    }
    
    print $fh "REMARK Chains\nREMARK\n";
    
    # First write out all the components and the interactions
    my @keys = $complex->keys->flatten;
    my $char = ord('A');
    foreach my $key (@keys) {
    	my $model = $complex->get($key);
    	my $seq = $model->query;
    	my $dom = $model->subject;
    	
    	print $fh "REMARK CHAIN ", chr($char), " ", $model->gene(), " ";
    	foreach my $score ($model->scores->keys->flatten) {
    		print $fh "${score}=", $model->scores->at($score), " ";
    	}
    	print "\n";
    	
    	print $fh "REMARK ", $dom->file, ' ', $dom->id, " { ", $dom->descriptor, " }\n";
    	print $fh "REMARK \n";
    	
    	# TODO BUG wrong if model has more than 26 chains
    	$char++;
    }
    
    # Just delegate all domains in the complex to DomainIO::stamp
    my $io = SBG::DomainIO::pdb->new(fh=>$fh);
    $io->write($complex->domains->flatten);

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
