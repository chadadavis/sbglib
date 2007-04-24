#!/usr/bin/env perl

package EMBL::Utils;
use base qw(Exporter);
our @EXPORT = qw(
                 verbose
                 min
                 max
                 sum
                 avg
                 stddev
                 sequence
                 rearrange
                 slurp
                 spit
                 nlines
                 nhead
                 run
                 seq2fasta
                 seq2flat
                 get_seq
                 thresh
                 put
                 wlock
                 );

use File::Temp qw(tempfile);
use Term::ANSIColor qw(:constants);
use File::Basename;
use File::Spec::Functions qw/rel2abs catdir/;
use Bio::DB::GenPept;

# GenPept handle
our $gp;

our $install_dir = rel2abs(dirname(__FILE__));
our $data_dir = catdir($install_dir, 'data');
our $cache_dir = catdir($install_dir, 'cache');

our $sp_cache = "${data_dir}/sp_cache";

################################################################################

# Print diagnostic/debugging messages
sub verbose  {
    return unless defined($::DEBUG) && $::DEBUG;
    my ($pkg, $file, $line, $func) = caller(1);
    $line = sprintf("%4d", $line);
    print STDERR 
#         BLUE, ">$file|$line|$func|", 
        BLUE, ">$pkg|$line|$func|", 
        GREEN, "@_\n", 
        RESET;
}

# Minimum of a list
sub min {
    my $x = shift @_;
    $x = $_ < $x ? $_ : $x for @_;
    return $x;
}

# Maximum of a list
sub max {
    my $x = shift @_;
    $x = $_ > $x ? $_ : $x for @_;
    return $x;
}

# Sum of a list
sub sum {
    my $x = 0;
    $x += $_ for @_;
    return $x;
}

# Average of a list
sub avg {
    # Check if we were given a reference
    my $r = $_[0];
    my @list = (ref $r) ? @$r : @_;
    return 0 unless @list;
    my $sum = 0;
    $sum += $_ for @list;
    return $sum / @list;
}

# Stddev of a list
sub stddev {
    # Check if we were given a reference
    my $r = $_[0];
    my @list = (ref $r) ? @$r : @_;
    return 0 unless @list;
    my $sum = 0;
    my $avg = avg(\@list);
    for (my $i = 0; $i < @list; $i++) {
        $sum += ($list[$i] - $avg)**2;
    }
    return sqrt($sum/(@list - 1));
}

# Creates a sequence of numbers (similar to in R)
sub sequence {
    my ($start, $inc, $end) = @_;
    my @a;
    for (my $i = $start; $i <= $end; $i+=$inc) {
        push @a, $i;
    }
    return @a;
}

# Support for named function parameters. E.g.:
# func(-param1=>2, -param3=>"house");
sub rearrange  {
    # The array ref. specifiying the desired order of the parameters
    my $order = shift;
    # Make sure the first parameter, at least, starts with a -
    return @_ unless (substr($_[0]||'',0,1) eq '-');
    # Make sure we have an even number of params
    push @_,undef unless $#_ %2;
    my %param;
    while( @_ ) {
        (my $key = shift) =~ tr/a-z\055/A-Z/d; #deletes all dashes!
        $param{$key} = shift;
    }
    map { $_ = uc($_) } @$order; # for bug #1343, but is there perf hit here?
    # Return the values of the hash, based on the keys in @$order
    # I.e. this return the values sorted by the order of the keys
    return @param{@$order};
} # rearrange

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

# Run a shell command on given input file, returns path to output file
sub run {
    my ($in, $cmd) = @_;
    my ($fh, $out) = tempfile("/tmp/disoconsXXXXXXXXXX", UNLINK=>!$::DEBUG);
    close $fh;
    # Use eval to substitute the current values of $in and $out
    $cmd = eval "\"$cmd\"";
    verbose("cmd:\n$cmd");
    unless (system($cmd) == 0) {
        print STDERR "Failed to run:\n\t$cmd\n";
        return 0;
    }
    return $out;
}

# Write sequence object to (auto-unlinked) temp file (fasta format)
sub seq2fasta {
    my ($seq) = @_;
    my ($temp_fh, $temp_name) = tempfile("/tmp/disoconsXXXXXXXXXX", 
                                         UNLINK=>!$::DEBUG);
    my $seq_out = Bio::SeqIO->new(-format=>'Fasta', -fh=>$temp_fh);
    $seq_out->write_seq($seq);
    close $temp_fh;
    return $temp_name;
}

# Write a sequence object to (auto-unlinked) temp file (raw sequence format)
sub seq2flat {
    my ($seq) = @_;
    my ($temp_fh, $temp_name) = tempfile("/tmp/disoconsXXXXXXXXXX", 
                                         UNLINK=>!$::DEBUG);
    print $temp_fh $seq->seq(), "\n";
    close $temp_fh;
    return $temp_name;
}

# Allows Bio::Seq and paths to Fasta files to be used as parameters 
# interchangeablly. 
# I.e. we want a Bio::Seq in the end, if we get a file, it's parsed in
sub get_seq {
    my ($thing) = @_;
    if (UNIVERSAL::isa($thing, "Bio::PrimarySeqI")) {
        return $thing;
    } elsif (-r $thing) {
        # If it's a file, read a fasta sequence from it
        my $in = Bio::SeqIO->new(-format=>'Fasta', -file=>"<$thing");
        return $in->next_seq();
    } else {
        return undef;
    }
}

# Converts analogue values to binary, given a threshold
# Something like this is probably already provided by the PDL
sub thresh {
    my ($ref, $thresh) = @_;
    for (my $i = 0; $i < @$ref; $i++) {
        $ref->[$i] = $ref->[$i] > $thresh;
    }
}

# Prints an arry with indices in tabular form in a temp text file, for gnuplot
sub put {
    my ($array) = @_;
    my ($fh, $out) = tempfile("/tmp/disoconsXXXXXXXXXX", UNLINK=>!$::DEBUG);
    for (my $i = 1; $i < @$array; $i++) {
        print $fh "$i ", $array->[$i], "\n";
    }
    close $fh;
    return $out;
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


