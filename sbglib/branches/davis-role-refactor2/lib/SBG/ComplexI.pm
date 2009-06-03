#!/usr/bin/env perl

=head1 NAME

SBG::ComplexI - Simplified complex representation (a L<Moose::Role>)

=head1 SYNOPSIS

 package SBG::Complex::MyComplexImplementation;
 use Moose;
 with qw/SBG::ComplexI/;


=head1 DESCRIPTION

A state-holder for L<SBG::Traversal>.  L<SBG::Assembler> uses L<SBG::Complex> to
hold state-information while L<SBG::Traversal> traverses an L<SBG::Network>.

In short, an L<SBG::ComplexI> is one of many
solutions to the protein complex assembly problem for a give set of domains.

=head1 SEE ALSO

L<SBG::DomainI> , L<SBG::Assembler> , L<SBG::Traversal>

=cut

################################################################################

package SBG::ComplexI;
use Moose::Role;

with 
    'SBG::Role::Storable',
    'SBG::Role::Dumpable',
    'SBG::Role::Clonable',
    ;


use Module::Load;

# Default type for created domains:
use SBG::Domain;


################################################################################
=head2 name

Just for keeping track of which complexes correspond to which networks

=cut
has 'name' => (
    is => 'ro',
    isa => 'Str',
    default => '',
    );


################################################################################
=head2 type

The sub-type to use for any dynamically created objects. Whatever type should
implement the L<SBG::DomainI> role.

=cut
has 'type' => (
    is => 'rw',
    isa => 'ClassName',
    required => 1,
    default => 'SBG::Domain',
    );

# ClassName does not validate if the class isn't already loaded. Preload it here.
before 'type' => sub {
    my ($self, $classname) = @_;
    return unless $classname;
    Module::Load::load($classname);
};


################################################################################
=head2 transform

 Function: Transform this object by the given transformation
 Example :
 Returns : 
 Args    : L<SBG::TransformI>

=cut
requires 'transform';


################################################################################
=head2 size

 Function: Number of modelled components in the current complex assembly
 Example : $assembly->size;
 Returns : Number of components in the current complex assembly
 Args    : NA

=cut
requires 'size';


################################################################################
=head2 rmsd

 Function: RMSD of entire model vs. the corresponding subset of the native
 Example : 
 Returns : RMSD between the complexes
 Args    : 

Domains are associated by name. Domains present in one complex but not the other
are not considered.

Undefined when no common template domains.

=cut
requires 'rmsd';


################################################################################
no Moose::Role;
1;

