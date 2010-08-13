#!/usr/bin/env perl

=head1 NAME

SBG::Role::Scorable - 

=head1 SYNOPSIS

with 'SBG::Role::Scorable';

=head1 DESCRIPTION


=head1 SEE ALSO


=cut



package SBG::Role::Scorable;
use Moose::Role;

# Also a functional interface
use base qw/Exporter/;
our @EXPORT_OK = qw/group_scores/;

use Moose::Autobox;



=head2 scores

 Function: 
 Example : 
 Returns : 
 Args    : 

Note that using lazy_build will cause the default to be reset when accessing the attribute after it has been cleared. In contrast, using 'default' will leave the attribute undefined after a clear.

=cut
has 'scores' => (
    is => 'rw',
    isa => 'HashRef',
    lazy_build => 1, # Re-built (to the default) after a clear
#    default => sub { {} }, # Left undefed after a clear
    clearer => 'clear_scores',
    );
sub _build_scores {
    return {} ;
}



=head2 group_scores

 Function: 
 Example : 
 Returns : 
 Args    : 

Given an array of Scorable objects, extract the 'scores' and populate a
Hashref of ArrayRefs

E.g. converts

 [ { scores=>{size=>10,weight=>3} } , { scores=>{size=>7,weight=>2} } ]

to

 { size=>[10,7], weight=>[3,2] }
 

=cut
sub group_scores {
    my ($array) = @_;
    my $hash = {};
    foreach my $eachhash ($array->flatten) {
        foreach my $key ($eachhash->keys->flatten) {
            $hash->{$key} ||= [];
            $hash->{$key}->push($eachhash->{$key});
        }
    }
    return $hash;
} # group_scores




no Moose::Role;
1;


