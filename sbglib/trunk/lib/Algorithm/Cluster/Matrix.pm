#!/usr/bin/env perl
=head1 NAME

=head1 SYNOPSIS

use Algorith::Cluster::Matrix;
my $m = Algorithm::Cluster::Matrix->new(
    measure=>sub{mydistance(@_)},objects=\@myarray);
my $distmatrix =  $m->distancematrix;

=head1 DESCRIPTION

A utility package for L<Algorithm::Cluster>

Computes a lower-diagonal distance matrix fit for being based to 
C<Algorithm::Cluster::treecluster>

Of course, you could also get a aimilarity matrix, if your function measures
similarities. 

=cut

package Algorithm::Cluster::Matrix;
use Moose;
has 'measure' => (
    is=>'rw',
    isa=>'CodeRef',
    );

has 'objects' => (
    is => 'rw',
    isa => 'ArrayRef',
    );
    
sub distancematrix {
    my ($self, ) = @_;
    my $measure = $self->measure;
    my $objects = $self->objects;
    # Lower diagonal distance matrix
    my $distances = [];
    for (my $i = 0; $i < @$objects; $i++) {
        $distances->[$i] ||= [];
        for (my $j = $i+1; $j < @$objects; $j++) {
            # Column-major order, to produce a lower-diagonal distance matrix      
            $distances->[$j][$i] = $measure->($objects->[$i], $objects->[$j]);
        }
    }
    return $distances;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
