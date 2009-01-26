#!/usr/bin/env perl

=head1 NAME

SBG::Template - Utilities for finding/creating Template objects

=head1 SYNOPSIS

 use SBG::Template;


=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::Interaction>


=cut

################################################################################

package SBG::Template;
use SBG::Root -base;

our $db = "/g/russell2/davis/p/ca/benchmark/search_bench_part8.out-robs"

use overload (
    '""' => '_asstring',
    );


################################################################################

sub new () {
    my ($class, %o) = @_;
    my $self = { %o };
    bless $self, $class;
    $self->_undash;

    return $self;
}

# TODO also provide search on sequences
sub search {
    my ($dom1, $dom2) = @_;

    my $t = new SBG::Template(-stuff=>1);
    return $t;
}

sub _asstring {
    my ($self) = @_;
#     return $self->primary_id;

}



###############################################################################

1;

__END__
