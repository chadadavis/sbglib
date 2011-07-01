#!/usr/bin/env perl

=head1 NAME

SBG::NetworkIO::html - 

=head1 SYNOPSIS

=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::Network> , L<SBG::InteractionIO::html>

=cut



package SBG::NetworkIO::html;
use Moose;

with qw/
SBG::IOI
/;


use SBG::InteractionIO::html;



=head2 write

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
use Data::Dump qw/dump/;
sub write {
    my ($self, $graph) = @_;
    # Delegate to InteractionIO
    my $iactionio = new SBG::InteractionIO::html(%$self);


    my @edges = $graph->edges;

    @edges = 
        sort {my($a1,$b1)=@$a;my($a2,$b2)=@$b; "$a1 $b1" cmp "$a2 $b2" } @edges;
    foreach my $e (@edges) {
        my ($u, $v) = @$e;
        # Names of attributes for this edge
        my @interactions;
        foreach my $attr ($graph->get_edge_attribute_names($u, $v)) {
            # The actual interaction object for this template
            push @interactions, $graph->get_interaction_by_id($attr);
        }
        $iactionio->write(@interactions);
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
