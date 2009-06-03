#!/usr/bin/env perl

=head1 NAME

SBG::Domain - Represents a domain of a protein structure. 

=head1 SYNOPSIS

 use SBG::Domain;

=head1 DESCRIPTION

A Domain is defined, according to STAMP, as one of:
1) ALL : All chains in a structure entry
2) CHAIN X : A complete chain, for some X in [A-Za-z0-9_]
3) B 12 _ to B 233 _ : An arbitrary segment of a chain
4) Any number of combinations of 2) and 3), e.g. 
  CHAIN B A 3 _ to A 89 _ C 232 _ to C 321 _
 

=head1 SEE ALSO

L<SBG::Types> , L<SBG::DomainIO> , L<SBG::CofM> , L<SBG::Transform>,
L<SBG::DomainI>

http://www.compbio.dundee.ac.uk/manuals/stamp.4.2/node29.html

=cut

################################################################################

package SBG::Domain;
use Moose;
use MooseX::StrictConstructor;

# Defines what must be implemented to represent a 3D structure
with qw/
SBG::DomainI 
/;

use Module::Load;

# Some regexs for parsing PDB IDs and descriptors
use SBG::Types qw/$re_chain $re_chain_seg/;

use SBG::TransformI;
use Scalar::Util qw(refaddr);

use overload (
    '""' => '_asstring',
    '==' => '_equal',
    fallback => 1,
    );


################################################################################
# Accessors


=head2 pdbid

PDB identifier, from which this domain comes
=cut
has 'pdbid' => (
    is => 'rw',
    isa => 'SBG.PDBID',
    );


=head2 descriptor

STAMP descriptor, Examples:

ALL
A 125 _ to A 555 _
CHAIN A
CHAIN A B 12 _ to B 211 _
B 33 _ to B 99 _ CHAIN A

See L<SBG::Types>
=cut
has 'descriptor' => (
    is => 'rw',
    isa => 'SBG.Descriptor',
    default => 'ALL',
    # Coerce from 'Str', defined in SBG::Types
    coerce => 1,
    );


################################################################################
=head2 scopid

 Function:
 Example :
 Returns : 
 Args    :

SCCS: e.g.: a.1.1.1-1

=cut
has 'scopid' => (
    is => 'rw',
    isa => 'Str',
    trigger => \&_from_scop,
    );

=head2 file

Path to PDB/MMol file.

This can be blank and STAMP will look for thas file based on its ID, which must
begin with the PDB ID for the domain.

=cut
has 'file' => (
    is => 'rw',
    isa => 'SBG.File',
    );


################################################################################
=head2 transformation

 Function: The L<SBG::Transform> describing any applied transformations
 Example :
 Returns : 
 Args    :

This attribute is imported automatically in consuming classes. But you may
override it.

This defines where the domain is in space at any point in time.
=cut
has 'transformation' => (
    is => 'rw',
    isa => 'SBG::Transform',
    required => 1,
    default => sub { new SBG::Transform },
    );


# Record linkages to other domains This does not define where the domain
# currently is, but identifies the linking transformation that was used to join
# it into another complex.
has 'linker' => (
    is => 'rw',
    isa => 'SBG::Transform',
    required => 1,
    default => sub { new SBG::Transform },
    );


# Record clashes for subsequent scoring
has 'clash' => (
    is => 'rw',
    isa => 'Num',
    default => 0,
    );


################################################################################
# Methods required by SBG::DomainI

# TODO should create warnings here

sub dist { return }
sub sqdist { return }
sub rmsd { return }
sub evaluate { return }

sub volume { return }
sub overlap { return }
sub overlaps { return }


################################################################################
=head2 transform

 Function: 
 Example : $self->transform(new SBG::Transform); # no-op
 Returns : $self
 Args    : L<SBG::Transform>

In this parent class, this simply updates the cumulative L<SBG::Transform> but
does not transform any structures. Subclasses are expected to L<Moose::override>
this method and to continue to call L<Moose::super>, so that the cumulative
transform stays up-to-date.

=cut
sub transform {
    my ($self,$newtrans) = @_;
    return $self unless defined($newtrans);

    # Update the cumulative transformation
    my $prod = $newtrans x $self->transformation;
    $self->transformation($prod);
    return $self;

} # transform



################################################################################
# Additional public methods


################################################################################
=head2 id

Combines the PDBID and the descriptor into a short ID.

E.g. 2nn6A13A122 => 2nn6 { A 13 _ to A 122 _ }

First four characters are the PDB ID.
A unique domain descriptor is then appended.

See also L<uniqueid>

=cut
sub id {
    my ($self) = @_;
    my $str = $self->pdbid;
    $str .= ($self->_descriptor_short || '');
    return $str;
} 


################################################################################
=head2 uniqueid

A unique ID, for use with STAMP.

In addition to L<id>, a unique ID for the transformation, if defined, is
appended.

NB If the L<SBG::Domain> contains a L<SBG::Transform>, the unique ID will be
different after read/write or after serializing and deserializing. This is
because the ID is simply the memory address of the Transform. It will be
different for two copies of the same transform.

=cut
sub uniqueid {
    my ($self) = @_;
    my $str = $self->id();
    # Get the memory address of some relevant attribute object, 
    my $rep = $self->transformation;
    $str .= $rep ? sprintf("-0x%x", refaddr($rep)) : '';
    return $str;
} 


################################################################################
=head2 wholechain

 Function:
 Example :
 Returns : Whether descriptor corresponds to one-and-only-one full chain
 Args    :

True when this domain consists of only one chain, and that entire chain

See als L<fromchain>
=cut
sub wholechain {
    my ($self) = @_;
    my ($chain) = $self->descriptor =~ /^\s*CHAIN\s+(.)\s*$/i;
    return $chain;
}



################################################################################
=head2 continuous

 Function:
 Example :
 Returns : 
 Args    :

Whether this domain is continous along a single protein chain.

The *entire* descriptor matches one of:
1) ALL
2) CHAIN X for some valid X =~ /$re_chain_id/
3) X i _ to X j _ for some valid X =~ /$re_chain_id/ and integers i j

See Also L<wholechain>

=cut
sub continuous {
    my ($self,@args) = @_;
    return $self->descriptor =~ /^(ALL)|$re_chain_seg$/;

} # continuous


################################################################################
=head2 asstamp

 Function:
 Example :
 Returns : 
 Args    :

String representing domain in STAMP format

=cut
sub asstamp {
    my ($self, %o) = @_;
    # Default to on, unless already set
    $o{trans} = 1 unless defined $o{trans};
    my $str = 
        join(" ",
             $self->file  || '',
             $self->uniqueid || '',
             '{',
             $self->descriptor || '',
        );
    # Append any transformation
    if ($o{trans} && $self->transformation) {
        $str .= " \n" . $self->transformation->ascsv . "\}\n";
    } else {
        $str .=  " \}\n";
    }
    return $str;

} # asstamp


################################################################################
=head2 hash

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub hash {
    my ($self) = @_;
    return "$self";
}


################################################################################
# Private


################################################################################
=head2 _asstring

 Function: Resturns a string representation of this domain.
 Example : print "Domain is $dom"; # automatic stringification
 Returns : string
 Args    : NA

=cut
sub _asstring {
    my ($self) = @_;
    my $s = ($self->pdbid || '') . ($self->_descriptor_short || '');
    return $s;
}


################################################################################
=head2 _equal

 Function:
 Example :
 Returns : 
 Args    :

Are two domains effectively equal.
This includes the external 3D representation of the domain.
=cut
sub _equal {
    my ($self, $other) = @_;
    # Must be of the same type
    return 0 unless defined $other && blessed($self) eq blessed($other);
    # Shortcut: Obviously equal if at same memory location
    return 1 if refaddr($self) == refaddr($other);
    # Fields, from most general to more specific
    my @fields = qw(pdbid descriptor file);
    foreach (@fields) {
        # If any field is different, the containing objects are different
        return 0 if 
            $self->$_ && $other->$_ && $self->$_ ne $other->$_;
    }
    # Transformations. If not defined, then assume the objects are equivalent 
    my $res = _attr_eq($self->transformation, $other->transformation);
    return defined($res) ? $res : 1;

} # _equal


################################################################################
=head2 _attr_eq

 Function:
 Example :
 Returns : 
 Args    :

Equality of potentially undef attributes
Returns:
undef when both undef
0 if exactly one undef, or if different classes
otherwise: returns $a == $b

=cut
sub _attr_eq {
    my ($a, $b) = @_;
    # Not unequal if both undefined
    return unless defined($a) || defined($b);
    # Unequal if one defined and other undefined
    return 0 if defined($a) xor defined($b);
    # Unequal if of different types
    return 0 unless blessed($a) eq blessed($b);
    
    return $a == $b;
}


################################################################################
=head2 _descriptor_short

 Function:
 Example :
 Returns : 
 Args    :

Converts: first line to second:

 'B 234 _ to B 333 _ CHAIN D E 5 _ to E 123 _'
 'B234_B333_DE5_E123_'

=cut
sub _descriptor_short {
    my ($self) = @_;
    my $descriptor = $self->descriptor;
    $descriptor =~ s/CHAIN//g;
    $descriptor =~ s/to//gi;
    $descriptor =~ s/\s+//g;
    return $descriptor;
}


################################################################################
=head2 _from_scop

 Function:
 Example :
 Returns : 
 Args    :

# Parse SCOP ID into PDB ID and descriptor
=cut
sub _from_scop {
    my ($self,$scopid) = @_;

#     cluck("Not implemented");

} # _from_scop



################################################################################
__PACKAGE__->meta->make_immutable;
1;

