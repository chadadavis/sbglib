#!/usr/bin/env perl

=head1 NAME

SBG::PointHash - A 3-dimensional geometric hash

=head1 SYNOPSIS

 use SBG::PointHash;
 my $h = new SBG::PointHash(
    resolution=>1, # default
    );
 $h->put($x,$y,$z,
    size=>4.5, # optional
    );
  if (my $conflict = $h->at($x,$y,$z,size=>2)) {
    print "$conflict is already at $x,$y,$z";
  }


=head1 DESCRIPTION




=head1 SEE ALSO


The (incomplete) interface is based on L<Moose::Autobox::Hash>

       at
       put
       exists
       keys
       values
       kv
       slice
       meta

=cut

################################################################################

package SBG::PointHash;


use Math::Round qw/nearest/;

use SBG::HashFields;

=head2 pt

HashRef field. Stores stringified points
=cut
hashfield 'pt', 'pts';


################################################################################
# Public


################################################################################
=head2 new

 Function: 
 Example : 
 Returns : 
 Args    : 

_gh is a hash of ArrayRef

=cut
sub new {
    my ($class, %self) = @_;
    my $self = { %self };
    bless $self, $class;
    $self->{_hash} ||= {};
    $self->{binsize} ||= 1;
    return $self;
}







################################################################################
1;

