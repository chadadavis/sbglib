#!/usr/bin/env perl

=head1 NAME

EMBL::Templat - 

=head1 SYNOPSIS



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

package EMBL::Template;

use lib "..";

use overload (
    '""' => 'stringify',
    );


################################################################################
=head2 new

 Title   : new
 Usage   : 
 Function: 
 Returns : 
 Args    :

=cut

sub new {
    my ($class, $component1, $component2, $template1, $template2) = @_;
    my $self = {};
    bless $self, $class;

    my $components = {
        $component1 => $template1,
        $component2 => $template2,
    };
    $self->{components} = $components;

    return $self;

} # new


sub stringify {
    my ($self) = @_;
    my $str;
    my @keys = keys %{$self->{components}};
    $str .= "@keys";
    foreach my $key (@keys) {
        $str .= " " . $self->{components}{$key};
    }
    return $str;
}



###############################################################################

1;

__END__
