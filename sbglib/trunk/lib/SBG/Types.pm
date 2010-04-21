#!/usr/bin/env perl

=head1 NAME

SBG::Types - 

=head1 SYNOPSIS

 use SBG::Types

=head1 DESCRIPTION

NB coercion will only happen when the input type does not already satisfy the 
type constraints. It will not happen by default in every case.


=head1 SEE ALSO

L<Moose::Util::TypeConstraints>

=cut



package SBG::Types;
use Moose;
use Moose::Util::TypeConstraints;

extends qw/Moose::Object Exporter/;

our @EXPORT_OK = qw/
$pdb41 $re_pdb 
$re_chain_id $re_chain 
$re_descriptor $re_ic $re_pos
$re_seg $re_chain_seg 
/;


# A file path 
subtype 'SBG.File' 
    => as 'Str'
    => where { -f $_ };


# File open mode specifiers. See perldoc -f open
our $re_mode = '\+?(<|>|>>)?';
# File with open-mode spec
subtype 'SBG.FileMode'
    => as 'Str'
    # First part is (optional) mode spec, second part must be file path
    => where { /^\s*$re_mode\s*(.*?)\s*$/ && -f $2 };


our $re_chain_id = "[A-Za-z0-9_]";
subtype 'SBG.ChainID'
    => as 'Str',
    => where { /^$re_chain_id$/ };


our $re_pdb = '\d[a-z0-9]{3}';
subtype 'SBG.PDBID'
    => as 'Str',
    => where { /^$re_pdb$/ };
# Force lc (lowercase)
coerce 'SBG.PDBID'
    => from 'Str'
    => via { lc $_ };


# Splits e.g. 2nn6A into (2nn6,A)
# Captures: $1 is PDB ID, $2 is 1-char chain ID
our $pdb41 = "($re_pdb)($re_chain_id)";


# STAMP chain descriptor
our $re_chain = 'CHAIN\s+' . $re_chain_id;

# Residue insertion code (character, STAMP uses _ for undefined)
our $re_ic = '[_a-zA-Z]';

# NB: Residue IDs can be negative
our $re_pos = '-?\d+';

# A segment, e.g. A 134 _ to A 233 A
our $re_seg = 
    $re_chain_id . '\s+' . $re_pos . '\s+' . $re_ic . '\s+to\s+' .
    $re_chain_id . '\s+' . $re_pos . '\s+' . $re_ic;


# A whole chain or a subsegment
# Captures: $1 is chain descriptor, $2 is segment descriptor
our $re_chain_seg = "($re_chain)|($re_seg)";


# (whole-chain or segment), repeated, white-space separated
# Captures: ...
our $re_chain_segs =  "($re_chain_seg)(\\s+($re_chain_seg))*";


# A STAMP descriptor can also be "ALL" for all residues of all chains
our $re_descriptor = "ALL|($re_chain_segs)";


subtype 'SBG.Descriptor'
    => as 'Str',
    # Disallow multiple whitespace blocks
    => where { /^\s*($re_descriptor)\s*$/ && ! /\s\s+/ };
# Remove extra whitespace
coerce 'SBG.Descriptor'
    => from 'Str'
    => via { s/\s+/ /g; $_ };



__PACKAGE__->meta->make_immutable;
no Moose::Util::TypeConstraints;
no Moose;
1;
