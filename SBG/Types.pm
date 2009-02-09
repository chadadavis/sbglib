#!/usr/bin/env perl

=head1 NAME

SBG::Types - 

=head1 SYNOPSIS

 use SBG::Types

=head1 DESCRIPTION

...

=head1 SEE ALSO

L<Moose::Util::TypeConstraints>

=cut

################################################################################

package SBG::Types;
use Moose;
use Moose::Util::TypeConstraints;

extends 'Exporter';
our @EXPORT_OK = 
    qw/$pdb41 $re_pdb $re_chain_id $re_chain $re_seg $re_chain_seg/;

subtype 'SBG.File' 
    => as 'Str'
    => where { -r $_ && -s $_ };

our $re_chain_id = "[A-Za-z0-9_]";
subtype 'SBG.ChainID'
    => as 'Str',
    => where { /^$re_chain_id$/ };

our $re_pdb = '\d\w{3}';
subtype 'SBG.PDBID'
    => as 'Str',
    => where { /^$re_pdb$/ };

# Splits e.g. 2nn6A into (2nn6,A)
our $pdb41 = "($re_pdb)($re_chain_id)";

our $re_chain = 'CHAIN\s+' . $re_chain_id;
# This is strict

# NB: Back referencing same chain with \g-1 (this goes back to prev. match)
our $re_seg = '(' . $re_chain_id . ')\s+\d+\s+_\s+to\s+\g-1\s+\d+\s+_';
our $re_chain_seg = "($re_chain)|($re_seg)";
# (whole-chain or segment), repeated, white-space separated
our $re_chain_segs =  "($re_chain_seg)(\\s+$re_chain_seg)*";

subtype 'SBG.Descriptor'
    => as 'Str',
    => where { 
        /^\s*(ALL|($re_chain_segs))\s*$/
};
coerce 'SBG.Descriptor'
    => from 'Str'
    => via { s/\s+/ /g; $_ };


1;
