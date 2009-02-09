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
L<SBG::RepresentationI>

http://www.compbio.dundee.ac.uk/manuals/stamp.4.2/node29.html

=cut

################################################################################

package SBG::Domain;
use Moose;
use MooseX::StrictConstructor;
with 'SBG::Storable';
with 'SBG::Dumpable';

use SBG::Types qw/$re_chain $re_chain_seg/;

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


=head2 file

Path to PDB/MMol file.

This can be blank and STAMP will look for thas file based on its ID, which must begin with the PDB ID for the domain.

=cut
has 'file' => (
    is => 'rw',
    isa => 'SBG.File',
    );


=head2 rep

3D representation of this domain in space.

This object is an instance of an implementor of L<SBG::RepresentationI>.
=cut
has 'representation' => (
    is => 'rw',
    does => 'SBG::RepresentationI',
    # Calling $domain->transform(...) delegates to 
    #   $domain->representation->transform(...);
    handles => [qw/transform/],
    );


################################################################################
# Public methods


=head2 uniqueid

A unique ID, for use with STAMP

First four characters must be the PDB ID (case insensitive).
The fifth character may optionally be a chain ID (case sensitive).
The address
=cut
sub uniqueid {
    my ($self) = @_;
    my $str = $self->pdbid;
    $str .= ($self->_descriptor_short || '');
    # Get the memory address of the representation object, 
    my $rep = $self->representation;
    $str .= $rep ? sprintf("-0x%x", refaddr($rep)) : '';
    return $str;
} # 


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
    return $self->descriptor =~ /^$re_chain$/;
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


=head2 fromchain

Returns the chain of this domain, if it comes from a single chain.

To determine if this domain is exactly one whole chain, use L<wholechain>. For
the whole STAMP descriptor, use L<descriptor>.
=cut
sub fromchain {
    my ($self) = @_;
    my $d = $self->_descriptor_short;
    my $ch = substr($d, 0, 1);
    # If the squashed descriptor looks like "A" or "A23A443" or "A2A44A55A66"
    return $d =~ /^($ch(\d+$ch\d+)?)+$/ ? $ch : undef;
}


################################################################################
=head2 asstamp

 Title   : asstamp
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :

String representing domain in STAMP format

=cut
sub asstamp {
    my ($self, %o) = @_;
    # Default to on, unless already set
    $o{newline} = 1 unless defined($o{newline});
    my $str = 
        join(" ",
             $self->file  || '',
             $self->uniqueid || '',
             '{',
             $self->descriptor || '',
        );
    # Append any transformation
    my $transstr = $self->representation->transformation->ascsv;
    $str .= $transstr ? (" \n${transstr}\}") : " \}";
    $str .= "\n" if defined($o{newline}) && $o{newline};
    return $str;

} # asstamp


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
    my $s = $self->pdbid . $self->_descriptor_short;
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
    return 0 unless defined $other;
    return 1 if refaddr($self) == refaddr($other);
    # Fields, from most general to more specific
    my @fields = qw(pdbid descriptor file);
    foreach (@fields) {
        return 0 if 
            $self->$_ && $other->$_ && $self->$_ ne $other->$_;
    }
    # Now compare the external 3D representations
    return 0 if 
        defined($self->representation) xor defined($other->representation);
    return 0 if
        defined $self->representation && defined $other->representation && 
        ! ($self->representation == $other->representation);

    # OK, everything's the same
    return 1;
}


################################################################################
=head2 _descriptor_short

 Function:
 Example :
 Returns : 
 Args    :

Converts: first line to second:

 'B 234 _ to B 333 _ CHAIN D E 5 _ to E 123 _';
 'B234B333DE5E123';

=cut
sub _descriptor_short {
    my ($self) = @_;
    my $descriptor = $self->descriptor;
    $descriptor =~ s/CHAIN//g;
    $descriptor =~ s/_//g;
    $descriptor =~ s/to//gi;
    $descriptor =~ s/\s+//g;
    return $descriptor;
}



################################################################################
__PACKAGE__->meta->make_immutable;
1;

