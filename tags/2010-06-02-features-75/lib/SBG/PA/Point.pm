#!/usr/bin/env perl

=head1 NAME

Point - 

=head1 SYNOPSIS

use SBG::PA::Point

=head1 DESCRIPTION


=head1 REQUIRES

* L<Moose>
* L<Math::Round>


=head1 SEE ALSO


=cut



package SBG::PA::Point;
use Moose;

use Math::Round qw/nearest/;
use overload (
    '""' => 'stringify',
    'cmp' => 'equal',
    fallback => 1,
    );

our $VERSION = "0.1";

=head2 pt

=cut
has 'pt' => (
    is => 'ro',
    isa => 'ArrayRef',
    default => sub { [0,0,0] },
    required => 1,
    );

=head2 label

=cut
has 'label' => (
    is => 'ro',
    isa => 'Str',
    default => '',
    required => 1,
    );

=head2 score

=cut
has 'score' => (
    is => 'ro',
    isa => 'Num',
    default => 0,
    required => 1,
    );

=head2 pval

=cut
has 'pval' => (
    is => 'ro',
    isa => 'Num',
    default => 1,
    required => 1,
    );



# Rounding resolution, can be a float
# See Math::Round::nearest()
our $resolution = .1;




=head2 random

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub random {
    my ($spread) = @_;
    $spread ||= 5;
    my $label = ('A'..'Z')[rand 26];
    my ($x,$y,$z) = map { $spread*rand() } (1..3);
    return new SBG::PA::Point('label'=>$label,'pt'=>[$x,$y,$z]);
}



=head2 dist

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub dist {
    my ($p1, $p2) = @_;
    my ($x1,$y1,$z1) = @{ $p1->pt };
    my ($x2,$y2,$z2) = @{ $p2->pt };
    sqrt(($x1-$x2)**2 + ($y1-$y2)**2 + ($z1-$z2)**2);
}



=head2 hash

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub hash {
    my ($self) = @_;
    my $rpts = _round($self->pt);
    return join(',', @$rpts);
}





sub stringify {
    my ($self) = @_;
    #return $self->label . $self->hash;
    return sprintf("%s-\(%.3f  %.3f  %.3f  %.3f  %.3f\)",$self->label,@{$self->pt},$self->score, $self->pval);
    #return sprintf("%s-\(%.3f  %.3f  %.3f\)",$self->label,@{$self->pt},$self->score, $self->pval);
}


sub _round {
    my ($coords) = @_;
    our $resolution;
    return [ map { nearest($resolution, $_) } @$coords ];
}


sub equal {
    my ($a, $b) = @_;
    return "$a" cmp "$b";
}


###############################################################################
__PACKAGE__->meta->make_immutable;
1;

__END__
