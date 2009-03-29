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
       delete

=cut

################################################################################

package SBG::PointHash;
use Moose;

# use Moose::Autobox;
with 'Moose::Autobox::Hash';


use Math::Round qw/nearest/;

=head 2

B<cellsize> defines the resolution of the points in 3D space

=cut
has 'cellsize' => (
    is => 'ro',
    isa => 'Num',
    default => 1,
    );

# 
has '_hash' => (
    is => 'ro',
    isa => 'HashRef',
    default => sub { {} },
    );


1;

__END__

################################################################################
# Public





################################################################################
=head2 put

 Function: 
 Example : 
 Returns : 
 Args    : 

# TODO FET allow point to have a size. When larger than cell size, occupies
# neighboring cells as well

=cut
sub put {
    my ($self,$coords,$val,%ops) = @_;
    $val = 1 unless defined $val;
    $coords = $self->_round($coords);
    warn "coords: @$coords\n";
    $self->_hash->{"@$coords"} = $val;

} # put


################################################################################
=head2 at

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub at {
    my ($self,$coords) = @_;
    $coords = $self->_round($coords);
    $self->_hash->{"@$coords"};

} # at


################################################################################
=head2 exists

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub exists {
    my ($self,$coords) = @_;
    $coords = $self->_round($coords);
    exists $self->_hash->{"@$coords"};

} # exists


################################################################################
=head2 delete

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub delete {
    my ($self,$coords) = @_;
    $coords = $self->_round($coords);
    delete $self->_hash->{"@$coords"};

} # delete


################################################################################
=head2 keys

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub keys {
    my ($self,) = @_;
    $self->_hash->keys;

} # keys


sub _round {
    my ($self, $coords) = @_;
    [ map { nearest($self->cellsize(), $_) } @$coords ];
}


################################################################################
__PACKAGE__->meta->make_immutable;
1;

