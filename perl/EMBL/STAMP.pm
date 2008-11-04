#!/usr/bin/env perl

# TODO this needs to be integrated into Bioperl
# In order to get around all the tmp file and file renaming junk

package EMBL::DOMFile;

use Utils;

# Creates ring/filamentous homo-oligomeric structures from monomers.  Applies
# the given transformation to a chain and repeats the transformation on newly
# created chains.

use File::Basename;

# STAMP-formatted transformation file
my $transfile = shift or die;
# Extend this many times (e.g. 1 turns a monomer into a dimer)
my $n = shift || 1;

################################################################################

my $base = basename($transfile, qw(.trans .dom));
my %trans = parsetrans($transfile);

for (my $i = 0; $i < $n; $i++) {


}

sub transform {
    my ($trans) = @_;

    system("transform -f $transfile -g -o out.pdb") == 0 or
        die("$!");
    rename "out.pdb", "in.pdb";

}

################################################################################

sub printtrans {
    my ($trans) = @_;


}

sub parsetrans {
    my ($transfile) = @_;
    open my $fh, $transfile;
    my %all;
    $all{'copy'} = [];
    my @existing;
    while (<$fh>) {
        next if /^%/;
        if (/^(\S+) (\S+) \{ ([^\}]+)/) {
            $all{'file'} = $1;
            $all{'name'} = $2;
            $all{'dom'} = $3;
            # The last line here includes a trailing }
            $all{'transform'} = [ <>, <>, <> ];
        } elsif (/^(\S+) (\S+) \{ (.*?) \}/) {
            push @{$all{'copy'}}, $_;
        } else {
            print STDERR "?: $_";
        }
    }
    close $fh;
    return %all;
}


