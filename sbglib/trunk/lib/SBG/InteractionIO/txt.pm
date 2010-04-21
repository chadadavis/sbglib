#!/usr/bin/env perl

=head1 NAME

SBG::InteractionIO::txt - 

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::IOI>

=cut



package SBG::InteractionIO::txt;
use Moose;

with qw/
SBG::IOI
/;

use Moose::Autobox;



=head2 write

 Function: tab-separated line of components and their templates 
 Example : $output->write($interaction);
 Returns : $self
 Args    : L<SBG::Interaction> - 

RRP41 RRP42  2br2 { A 108 _ to A 148 _ } 2br2 { D 108 _ to D 148 _ } 


=cut
sub write {
    my ($self, @interactions) = @_;
    my $fh = $self->fh or return;

    foreach my $iaction (@interactions) {
        next unless $iaction->nodes;
        my $nodes = [ $iaction->nodes ];
        my $models = $nodes->map({ $iaction->get($_) });
        my $doms = $models->map({ $_->subject });
        my $pdbs = $doms->map({ $_->pdbid });
        my $descrs = $pdbs->map({ $_->descriptor });

        printf $fh
            "%s\t%s\t%s\t{ %s }\t%s\t{ %s }",
            @$nodes, $pdbs->[0], $descrs->[0], $pdbs->[1], $descrs->[1];

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

} # read



__PACKAGE__->meta->make_immutable;
no Moose;
1;
