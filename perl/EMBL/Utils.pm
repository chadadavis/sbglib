#!/usr/bin/env perl

package EMBL::Utils;
use base qw(Exporter);
our @EXPORT = qw(
verbose
run
seq2fasta
seq2flat
get_seq
);

use File::Temp qw(tempfile);
use File::Basename;
use File::Spec;


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


################################################################################
1;
__END__


