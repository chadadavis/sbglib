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
subtype 'SBG.File' => as 'Str' => where { -f $_ };
subtype 'SBG.Dir' => as 'Str' => where { -d $_ };

# File open mode specifiers. See perldoc -f open
our $re_mode = '\+?(<|>|>>)?';

# File with open-mode spec
subtype 'SBG.FileMode' => as 'Str'

  # First part is (optional) mode spec, second part must be file path
  => where { /^\s*$re_mode\s*(.*?)\s*$/ && -f $2 };

# NB chain ID can be more than one char, in that case, should be converted to lc
our $re_chain_id = "[A-Za-z0-9_]*";
subtype
  'SBG.ChainID' => as 'Str',
  => where { /^$re_chain_id$/ };

our $re_pdb = '\d[A-Za-z0-9]{3}';
subtype
  'SBG.PDBID' => as 'Str',
  => where { /^$re_pdb$/ };

# Force lc (lowercase)
# This is no longer effective, since we now allow uppercase
coerce 'SBG.PDBID' => from 'Str' => via { lc $_ };

# Splits e.g. 2nn6A into (2nn6,A)
# Captures: $1 is PDB ID, $2 is chain ID (possibly 2-char)
our $pdb41 = "($re_pdb)($re_chain_id)";

# STAMP chain descriptor
our $re_chain = 'CHAIN\s+' . $re_chain_id;

# Residue insertion code (character, STAMP uses _ for undefined)
our $re_ic = '[_a-zA-Z]';

# NB: Residue IDs can be negative
our $re_pos = '-?\d+';

# A segment, e.g. A 134 _ to A 233 A
our $re_seg =
    $re_chain_id . '\s+' 
  . $re_pos . '\s+' 
  . $re_ic
  . '\s+to\s+'
  . $re_chain_id . '\s+'
  . $re_pos . '\s+'
  . $re_ic;

# A whole chain or a subsegment
# Captures: $1 is chain descriptor, $2 is segment descriptor
our $re_chain_seg = "($re_chain)|($re_seg)";

# (whole-chain or segment), repeated, white-space separated
# Captures: ...
our $re_chain_segs = "($re_chain_seg)(\\s+($re_chain_seg))*";

# A STAMP descriptor can also be "ALL" for all residues of all chains
our $re_descriptor = "ALL|($re_chain_segs)";

# In order for coercion to take place, the where clause needs to identify 
# everything that's disallowed.
subtype
  'SBG.Descriptor' => as 'Str',

  # Disallow multiple whitespace blocks
  # Disallow 2-char chain names (chain is always preceeded or followed by space)
  # Otherwise, 'ALL' would also be converted to 'Al', which we don't want
  => where { 
  	/^\s*($re_descriptor)\s*$/ && 
  	! /\s\s+/ && 
  	! / ([a-zA-Z])\1/ &&
	! /([a-zA-Z])\1 / 
  };

# Remove extra whitespace
# And convert two-char chain IDs to lc
# NB insertion codes can only be 1-char, so any occurrence of anything 2-char
# is a chain ID that needs to be lowercased
coerce 'SBG.Descriptor' 
	=> from 'Str' 
	=> via { s/([a-zA-Z])\1/lc($1)/eg; s/\s+/ /g; $_ };
	
__PACKAGE__->meta->make_immutable;
no Moose::Util::TypeConstraints;
no Moose;
1;
