#!/usr/bin/env perl

=head1 NAME

SBG::ComplexIO::report - A simple free form text report 

=head1 SYNOPSIS


=head1 DESCRIPTION

This is also included in the L<SBG::ComplexIO::stamp> and L<SBG::ComplexIO::pdb> outputs.

=head1 SEE ALSO

L<SBG::DomainIO::stamp> , L<SBG::ComplexIO::stamp> , L<SBG::Complex>

=cut



package SBG::ComplexIO::report;
use Moose;

with 'SBG::IOI';

use Carp;
use Log::Any qw/$log/;

use Moose::Autobox;


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
    
    print $fh "Output from Complex modelling\n\n";
    print $fh "Target ", $complex->targetid, "\n",
    print $fh "Model ", $complex->modelid, "\n";
    
    print $fh "Interactions\n\n";
    
    foreach my $iaction ($complex->interactions->values->flatten) {
    	print $fh "$iaction";
        my $source = $iaction->source;
    	print $fh " source=", $source if $source;
        my $weight = $iaction->weight;
    	print $fh " weight=", $weight if $weight;
    	foreach my $score ($iaction->scores->keys->flatten) {
    		print $fh " ${score}=", $iaction->scores->at($score);
    	}
    	print $fh "\n\n";
    }
    
    print $fh "Chains\n\n";
    
    # First write out all the components and the interactions
    my @keys = $complex->keys->flatten;
    my $char = ord('A');
    foreach my $key (@keys) {
    	my $model = $complex->get($key);
    	my $seq = $model->query;
    	my $dom = $model->subject;
    	
    	print $fh "CHAIN ", chr($char), " ", $model->gene(), " ";
    	foreach my $score ($model->scores->keys->flatten) {
    		print $fh "${score}=", $model->scores->at($score), " ";
    	}
    	print $fh "\n";
    	
    	print $fh "", $dom->file, ' ', $dom->id, " { ", $dom->descriptor, " }\n";
    	print $fh "\n";
    	
    	# TODO BUG wrong if model has more than 26 chains
    	$char++;
    }
    
    return $self;
} # write


=head2 read

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


__PACKAGE__->meta->make_immutable;
no Moose;
1;
