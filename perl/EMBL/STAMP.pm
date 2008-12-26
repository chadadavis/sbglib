#!/usr/bin/env perl

# TODO this needs to be integrated into Bioperl
# In order to get around all the tmp file and file renaming junk

package EMBL::STAMP;

require Exporter;
our @ISA = qw(Exporter);
# Automatically exported symbols
our @EXPORT    = qw(stampfile );
# Manually exported symbols
our @EXPORT_OK = qw();


# use Utils;

# Creates ring/filamentous homo-oligomeric structures from monomers.  Applies
# the given transformation to a chain and repeats the transformation on newly
# created chains.

use File::Basename;

# STAMP-formatted transformation file
# my $transfile = shift or die;
# Extend this many times (e.g. 1 turns a monomer into a dimer)
# my $n = shift || 1;

################################################################################

# my $base = basename($transfile, qw(.trans .dom));
# my %trans = parsetrans($transfile);




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

# returns EMBL::Transform
# Transformation will be relative to fram of reference of destdom
sub stampfile {
    my ($srcdom, $destdom) = @_;

    # STAMP uses lowercase chain IDs
    $srcdom = lc $srcdom;
    $destdom = lc $destdom;

    if ($srcdom eq $destdom) {
        # Return identity
        return new EMBL::Transform;
    }

    print STDERR "\tSTAMP ${srcdom}->${destdom}\n";
    my $dir = "/tmp/stampcache";
    `mkdir /tmp/stampcache` unless -d $dir;
#     my $file = "$dir/$srcdom-$destdom-FoR.csv";
    my $file = "$dir/$srcdom-$destdom-FoR-s.csv";

    if (-r $file) {
        print STDERR "\t\tCached: ";
        if (-s $file) {
            print STDERR "positive\n";
        } else {
            print STDERR "negative\n";
            return undef;
        }
    } else {
        my $cmd = "./transform.sh $srcdom $destdom $dir";
        $file = `$cmd`;
    }

    my $trans = new EMBL::Transform();
    unless ($trans->loadfile($file)) {
        print STDERR "\tSTAMP failed: ${srcdom}->${destdom}\n";
        return undef;
    }
    return $trans;
} 


sub parsetrans {
    my ($transfile) = @_;
    open(my $fh, $transfile);
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


################################################################################
1;
