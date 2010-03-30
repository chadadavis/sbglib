#!/usr/bin/env perl

=head1 NAME

PBS::ARGV

=head1 SYNOPSIS

use PBS::ARGV qw/qsub/;

# Will call: $0 $x, foreach $x in @ARGV
my @jobids = qsub();

# What's left in @ARGV in each PBS process will then just be a single parameter
# If PBS is not available, however, it just runs sequentially on the local host
foreach my $arg (@ARGV) {
    do_the_real_work($arg);
}


# You can also specify the command(s) to run yourself
# Will run: another-program with-another-argument $x, for each $x in @ARGV
my @jobids = qsub(cmd=>"another-program with-an-argument");


# With Getopt, give your PBS jobs the same options that you received
use Getopt::Long;
my %ops;
my $result = GetOptions(\%ops,'loglevel|l=s','logfile|f=s','debug|d:i');
my @jobids = qsub(options=>\%ops);


# Add any PBS directives as the elements of an array
my @jobids = qsub(directives=>['-m abe', '-N jobname', ...]);

# PBS directives are not parsed, with the exception of:
# -N will be set to the currently processed argument, if not otherwise given
# -J (job arrays) will cause $PBS_ARRAY_INDEX to be appended to the command line
my @jobids = qsub(directives=>[ '-J 0-15' ]);
# Will make the pbs job script run the command, for each $arg in @ARGV:
# myscript.pl $arg -J $PBS_ARRAY_INDEX
# And for each $arg, PBS will run with PBS_ARRAY_INDEX set to each of [0-15]

# I.e. $arg might be the name of a file listing all the input files to be
# processed then your script will just have to lookup the appropriate line in
# the file and that is the current file to be processed in the current sub-job.


=head1 DESCRIPTION

A quick-and-dirty approach to parallelize a script that processes multiple input
files.

In short, calling:

 $ ./myscript.pl file1.dat file2.dat ...

Will submit jobs to PBS, which each run:

 $ ./myscript.pl file1.dat
 $ ./myscript.pl file2.dat
 ...

The arguments to your script need not be existing files. This is just one use. They might as well be:

 $ ./parallel-download http://site1.com/page1.html http://site2.com/page2.html

Since the script recursively calls itself, it does not resubmit to PBS when it
determines it is already running under PBS. This is defined as the existance of
B<$ENV{PBS_ENVIRONMENT}>.


TODO BUG Fails when given command line switches. I.e. an option that has no argument. To get around this, use options that require a value only. E.g. do not use:

 app.pl -q

rather, use:

 app.pl -q 1

See the documentation for L<Getopt::Long>



=head1 SEE ALSO

This module makes few assumptions about the particular kind of PBS system you
are running. For more fine-grained PBS job control, see L<PBS::Client> and
L<PBS::Status>.

=head1 METHODS

=cut

package PBS::ARGV;
use strict;
use warnings;

use base qw/Exporter/;
our @EXPORT_OK = qw/qsub linen nlines/;
use vars qw($VERSION);
$VERSION = 0.01;


use Carp;
use File::Spec;
use File::Basename;
use File::Temp qw(tempfile);
use Log::Any qw/$log/;
use Getopt::Long;


################################################################################
=head2 qsub

 Function: 
 Example : 
 Returns : Array of job IDs submitted. A job ID will return -1 on failure.
 Args    : $cmd the program/script/command(s) to be run
           @directives PBS directives, as described the PBS manual

Submits one job to pbs, via B<qsub>, for each argument in B<@ARGV>.

Sets the current working directory of the executing job to the current
workign directory from when the job was submitted.

 qsub(directives=>[ '-N myjobname', '-J 0-15', '-m abe']);

=cut
sub qsub {
    my (%ops) = @_;

    # Already running in a PBS job, don't recurse
    if (defined $ENV{'PBS_ENVIRONMENT'}) {
        $log->debug('Running in PBS job');
        return;
    }
    
    return unless has_permission();

    my @jobids;
    my @failures;
    while (my $param = shift @::ARGV) {
        my $jobid = _submit($param, %ops);
        if ($jobid eq '-1') {
            push @failures, $param;
        } else {
            push @jobids, $jobid;
        }
    }

    # Restore ARGV with the ones that didn't submit
    @::ARGV = @failures;
    return @jobids;

} # qsub


# Do we have qsub on this system in the $PATH
sub has_bin {
    my ($bin) = @_;
    our $_qsubpath;
    return $_qsubpath if defined $_qsubpath;
    foreach my $dir (File::Spec->path()) {
        my $f = File::Spec->catfile($dir, $bin);
        $_qsubpath = $f if(-e $f && -x $f );
    }
    $_qsubpath ||= '';
    $log->debug("bin path: $_qsubpath");
    return $_qsubpath;

}


# Ability to connect to PBS server
sub has_permission {
    my $qstat = has_bin('qstat');
    return system("$qstat >/dev/null 2>/dev/null") == 0;
}


# Write and submit one PBS job script
sub _submit {
    my ($filearg, %ops) = @_;

    # Default: rerun same script
    # NB: this can be a relative path, because we 'cd' to $ENV{PWD} in the job
    my $cmdline = $ops{'cmd'} || $0;
    $cmdline .= " $filearg";

    # Command line options to pass on
    my %cmdops = $ops{'options'} ? %{$ops{'options'}} : ();
    # PBS directives
    my @directives = $ops{'directives'} ? @{$ops{'directives'}} : ();

    # Check explicitly for mailing address, append it to directives
    if ($cmdops{'M'}) {
        push @directives, "-M $cmdops{'M'}";
        # Notify on Abort, Begin, End
        push @directives, "-m abe";
        # Doesn't need to be passed on to job invocations
        delete $cmdops{'M'};
    }

    # Array? if -J directive given, also append \$PBS_ARRAY_INDEX to cmdline
    if ($cmdops{'J'}) {
        my $lastline = nlines($filearg) - 1;
        push @directives, "-J 0-$lastline";
        # NB this variable will be defined by the PBS environment when started
        # Each job will get a -J 5 where 5 varies from 0 to the lastline of file
        $cmdops{'J'} = '$PBS_ARRAY_INDEX';
    }

    # Add name, unless given
    unless (grep { /^-N/ } @directives) {
        my $base = basename $filearg;
        # Should begin with alphabetic char
        $base = 'j' . $base unless $base =~ /^[A-Za-z]/;
        # First 15 characters limit
        ($base) = $base =~ /^(.{1,15})/;
        push @directives, "-N $base";
    }

    # Add a dash to precede each argument name
    my @cmdops = map { '-' . $_ => $cmdops{$_} } keys %cmdops;
    $cmdline .= " @cmdops";

    # Explicitly inherit TMPDIR from parent process, to prevent PBS from overwriting it
    $ENV{'TMPDIR'} ||= File::Spec->tmpdir();

    my ($tmpfh, $jobscript) = tempfile("pbs_XXXXX", TMPDIR=>1);
    print $tmpfh "#!/usr/bin/env sh\n";
    print $tmpfh "#PBS $_\n" for @directives;
    print $tmpfh "export TMPDIR=\"$ENV{'TMPDIR'}\"\n";
    print $tmpfh "cd $ENV{PWD}\n";
    print $tmpfh "$cmdline\n";
    close $tmpfh;

    my $jobid = `qsub $jobscript`;
    unless ($jobid) {
        my $msg = "Failed: qsub $jobscript";
        $log->error($msg);
        print STDERR "$msg\n";
        $File::Temp::KEEP_ALL = 1;
        return -1;
    } else {
        chomp $jobid;
        $log->info("$jobid $filearg");
        print STDERR "$jobid $filearg $jobscript\n";
        return $jobid;
    }

} # _submit


# Returns the text of line #N of a file
# Counting is 0-based
# Line does not end with a newline
sub linen {
    my ($file, $n) = @_;
    open(my $fh, $file) or return;
    my $line;
    for (my $i = 0; defined($line = <$fh>) && $i < $n; $i++) {}
    return unless defined $line;
    chomp $line;
    return $line;
}


sub nlines {
    my ($file) = @_;
    open(my $fh, $file) or return;
    my $count = 0;
    $count++ while <$fh>;
    return $count;
}



1;
