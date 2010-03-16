#!/usr/bin/env perl

=head1 NAME

SBG::DomainSetI - A set of L<SBG::DomainI>

=head1 SYNOPSIS

 package SBG::Domain::MyDomainImplementation;
 use Moose;
 with 'SBG::DomainSetI'; 

 sub domains { return \@domains }

=head1 DESCRIPTION

If your class uses this role, it will need to define all the methods below.

=head1 SEE ALSO

L<SBG::DomainI>, L<Moose::Role>


=cut

################################################################################

package SBG::DomainSetI;
use Moose::Role;


with 'SBG::Role::Clonable';
with 'SBG::Role::Dumpable';
with 'SBG::Role::Storable';
with 'SBG::Role::Transformable';


################################################################################
=head2 domains

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
requires 'domains';




################################################################################
no Moose::Role;
1;

