#!/usr/bin/env perl

package EMBL::File;

use base qw(Exporter);
our @EXPORT = qw(
rmkdir
slurp
spit
linei
nlines
nhead
table
wlock
);

use File::Spec;
use File::Temp qw(tempfile);
use File::Basename;



################################################################################

# TODO POD
# Recursively creates a directory path
# i.e. rmkdir("a/b/c") or rmkdir("/usr/local/a/b/c")
# Will return success if the directory now exists
sub rmkdir {
    my ($dir) = @_;
    # Start at root, go through all
    $dir = File::Spec->rel2abs($dir);
    # Get whole hierarchy of subdirectory, one by one
    # Split on / or \ path separators
    my @tree = split(/\/|\\/, $dir);

    # Append the next level in each iteration, create directories recursively
    # Start at root
    my $d = File::Spec->catdir("");
    for my $t (@tree) {
        $d = File::Spec->catdir($d, $t);
        print STDERR ":$d:\n";
        mkdir $d;
    }
    return -d $dir;
}


# Slurps the contents of a (unopened) file (given path to file) into a string
sub slurp {
    my ($file) = @_;
    local $/;
    open my $fh, "<$file";
    my $data = <$fh>;
    close $fh;
    return $data;
}

# Spits anything into a file, creating/overwriting that file (given path)
sub spit {
    my ($file, $data) = @_;
    open my $fh, ">$file";
    print $fh $data;
    close $fh;
}




# Returns number of lines in file
sub nlines {
    my ($file) = @_;
    my $line = `wc -l $file`;
    my @elems = split /\s+/, $line;
    return shift @elems;
}

# Returns line number i from some file (0-based counting)
sub linei {
    my ($file, $i) = @_;
    # Open for reading only
    open my $fh, "<$file";
    # Read over the first $i - 1 lines
    for (my $j = 0; $j < $i; $j++) { <$fh> or return;}
    # Read line number i
    my $line = <$fh>;
    chomp $line;
    close $fh;
    return $line;
}

# Pop the first n lines of a file, and return them (useful for removing headers)
# File is re-written in-place w/o those lines
sub nhead {
    my ($n, $file) = @_;
    return 1 unless -r $file && -w $file;
    open FH, "<$file";
    my @lines = <FH>;
    close FH;
    # if $n negative, chop off all but the last |$n| lines
    if ($n < 0) { $n += @lines; }
    # The lines to be removed
    my @pop = @lines[0..$n-1];
#     verbose("Chopping first $n lines:\n", @pop);
    # The rest
    @lines = @lines[$n..$#lines];
    # write back out
    open FH, ">$file";
    print FH @lines;
    close FH;
    return @pop;
}


=head2 wlock

 Title   : wlock
 Usage   : my $lockfile = wlock("file.txt", 10); unlink $lockfile;
 Function: Sets a lock (as symlink) on the given file
 Returns : The link to the lock file, if it could be created, otherwise nothing
 Args    : The file that is to be exclusively opened.
           The number of attempts to try to lock the file. Default 5.

Routine fails, returning nothing, if it cannot create the lock within the given
number of attempts.

If you to test a lock without waiting, just set the number of attempts to 1.
Otherwise the function will sleep for a second between each attempt to give any
other processes a chance to finish what they are doing before attempting to lock
the file again.

The lock file returned by this method must be deleted by the caller after the
lock is no longer needed. E.g.:

my $database = "mydatabase.dat";
my $lockfile = wlock($database);
open (DB, ">$database");
# Read or write the file
close DB;
# Release the lock, so that other processes can access the data file
unlink $lockfile;

=cut

sub wlock {
    my $file = shift or return;
    my $attempts = shift || 5;
    my $lock = "${file}.lock";
    until (symlink("$ENV{HOSTNAME}-$$", $lock)){
        $attempts--;
        return unless $attempts > 0;
        sleep 1 + int rand(3);
        verbose("Waiting for lock file: $lock ($attempts)");
    }
    return $lock;
} # wlock


################################################################################
1;
__END__


