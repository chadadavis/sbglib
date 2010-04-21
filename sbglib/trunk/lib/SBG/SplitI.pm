#!/usr/bin/env perl

=head1 NAME

SBG::SearchI - 

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SEE ALSO


=cut



package SBG::SplitI;
use Moose::Role;




=head2 search

 Function: Splits a L<Bio::Seq> into multiple domains
 Example : 
 Returns : 
 Args    : A L<Bio::Seq>


=cut
requires 'split';




no Moose::Role;
1;

