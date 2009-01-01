#!/usr/bin/env perl

=head1 NAME

SBG::Seq - Additions to Bioperl's Bio::Seq

=head1 SYNOPSIS

use SBG::Seq;


=head1 DESCRIPTION


=head1 BUGS

None known.

=head1 REVISION

$Id: Prediction.pm,v 1.33 2005/02/28 01:34:35 uid1343 Exp $

=head1 APPENDIX

Details on functions implemented here are described below.
Private internal functions are generally preceded with an _

=cut

################################################################################

package Bio::Seq;

use overload (
    '""' => 'stringify',
    'cmp' => 'compare',
    'eq' => 'equal',

    );

# Other modules in our hierarchy
use lib "..";


################################################################################
=head2 

 Title   : 
 Usage   : 
 Function: 
 Returns : 
 Args    : 
           
=cut

sub stringify {
    my ($self) = @_;
    my $class = ref($self) || $self;
    return $self->accession_number;
}

sub equal {
    my ($a, $b) = @_;
    return 0 == compare($a, $b);
}

sub compare {
    my ($a, $b) = @_;
    return $a->accession_number cmp $b->accession_number;
}

###############################################################################

1;

__END__
