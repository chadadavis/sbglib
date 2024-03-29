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
our $VERSION = 20110929;
use 5.008;

use Carp;
use File::Spec;
use File::Basename;
use File::Temp qw(tempfile);
use Log::Any qw/$log/;
use Getopt::Long;
use Tie::File;
use IPC::Cmd;    # qw/can_run/;

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

    my @jobids;
    my @failures;

    # Number of command line arguments (e.g. files) to process per job,
    # default: 1
    my $blocksize = $ops{blocksize} || 1;
    my $nparams_submitted = 0;
    while (my $param = _block($blocksize)) {

        # Wait if queue overloaded
        _throttle($ops{throttle});
        my $jobid = _submit($param, %ops);
        if ($jobid eq '-1') {
            push @failures, @$param;
        }
        else {
            push @jobids, $jobid;
            $nparams_submitted += @$param;
        }
    }

    # Restore ARGV with the ones that didn't submit
    @::ARGV = @failures;

    # If we're on a TTY and not already in a PBS job
    if (-t STDOUT && !defined $ENV{PBS_ENVIRONMENT}) {
        print
            "Submitted $nparams_submitted args in ",
            scalar(@jobids), " jobs (x$blocksize)\n";
    }

    return @jobids;

}    # qsub

# Called when the module is loaded, will exit the process if successful
sub import {
    my ($self, @ops) = @_;

    # Parse out PBS-specific submission ops too
    our @pbs_ops = qw/cmd=s throttle=i directives=s blocksize=i J=s M=s/;
    push @ops, @pbs_ops;

    # This makes single-char options case-sensitive
    Getopt::Long::Configure('no_ignore_case');
    my %ops;
    my $result = GetOptions(\%ops, @ops);

    # Don't submit PBS jobs when:
    # Already running in a PBS job (i.e. don't recurse)
    # Only options given, but no arguments
    # No permission to submit to PBS
    if (   defined $ENV{PBS_ENVIRONMENT}
        || @ARGV == 0
        || !can_connect())
    {

        # Cleanup PBS-specific options
        %ops = _purge_ops(%ops);
        push @ARGV, map { '-' . $_ => $ops{$_} } keys %ops;
        return;
    }

    my @jobids = qsub(%ops);
    exit unless @ARGV;
}

# Ability to connect to PBS server
sub can_connect {
    our $qstat;
    $qstat ||= IPC::Cmd::can_run('qstat') or return;
    our $connected;

    #TODO DES use IPC:Cmd::run() here to set a 5 second timeout on the check
    $connected ||= system("$qstat >/dev/null 2>/dev/null") == 0;
    return $connected;
}

sub _block {
    my ($blocksize) = @_;
    my @block = map { shift @::ARGV } 1 .. $blocksize;

    # Workaround for unmatched shell glob
    # Otherwise we might submit a job to process the file ./stuff.*.dat
    #	@block = grep { defined && -r } @block;
    #	Not testing for existance of file, as they may not always be files
    @block = grep {defined} @block;
    return unless @block;
    return \@block;
}

sub _throttle {
    my ($throttle) = @_;

    return unless $throttle;
    my $njobs = _njobs();
    until ($njobs < $throttle) {
        print "Sleeping until $njobs < $throttle\n";
        sleep 60;
        $njobs = _njobs();
    }
}

sub _njobs {

    # All job IDs contain the server name
    our $server = 'cln035';
    my $jobs = `qstat -u \$USER`;
    chomp $jobs;
    my @jobs = split "\n", $jobs;
    @jobs = grep {/\.${server}/} @jobs;
    my $njobs = @jobs;
    return $njobs;
}

# Write and submit one PBS job script
sub _submit {
    my ($fileargs, %ops) = @_;
    our @pbs_ops;

    # Default: rerun same script
    # NB: this can be a relative path, because we 'cd' to $ENV{PWD} in the job
    my $cmdline = $ops{cmd} || $0;
    $cmdline .= " @$fileargs";

    # PBS directives
    my @directives = $ops{directives} || ();

    # Check explicitly for mailing address, append it to directives
    if ($ops{M}) {
        push @directives, "-M $ops{M}";
    }

    # Notify on Abort, Begin, End
    #     push @directives, "-m a";

    # Command line options to pass on
    # Remove our own PBS ops, leaving just the caller's own ops
    my %cmdops = _purge_ops(%ops);

    # Array? if -J directive given, also append \$PBS_ARRAY_INDEX to cmdline
    if ($ops{J}) {

        # NB if using array jobs, can only have one command line param, the file
        my @lines;
        tie @lines, 'Tie::File', $fileargs->[0];
        my $lastline = $#lines;
        push @directives, "-J 0-$lastline";

        # NB this variable will be defined by the PBS environment when started
        # Each job will get a -J 5 where 5 varies from 0 to the lastline of file
        $cmdops{J} = '$PBS_ARRAY_INDEX';
    }

    # Add name, unless given
    my ($name) = join(' ', @directives) =~ /-N (\S+)/;
    unless ($name) {
        $name = basename $fileargs->[0];

        # Should begin with alphabetic char
        $name = 'j' . $name unless $name =~ /^[A-Za-z]/;

        # First 15 characters limit
        ($name) = $name =~ /^(.{1,15})/;
        push @directives, "-N $name";
    }

    # Add a dash to precede each argument name
    my @cmdops = map { '-' . $_ => $cmdops{$_} } keys %cmdops;
    $cmdline .= " @cmdops";

    # Explicitly inherit TMPDIR from parent process,
    # to prevent PBS from overwriting it
    $ENV{TMPDIR} ||= File::Spec->tmpdir();

    my ($tmpfh, $jobscript) = tempfile("pbs_XXXXX", TMPDIR => 1);
    print $tmpfh "#!/usr/bin/env sh\n";
    print $tmpfh "#PBS $_\n" for @directives;
    print $tmpfh "export TMPDIR=\"$ENV{TMPDIR}\"\n";
    print $tmpfh "cd $ENV{PWD}\n";
    print $tmpfh "$cmdline\n";
    close $tmpfh;

    my $jobid = `qsub $jobscript`;

    #    my $jobid = 1;
    unless ($jobid) {
        my $msg = "Failed: qsub $jobscript (for $name)";
        $log->error($msg);
        print STDERR "$msg\n";
        $File::Temp::KEEP_ALL = 1;
        return -1;
    }
    else {
        chomp $jobid;
        my $njobs = _njobs();
        print "Submitted $jobid ($njobs jobs total) for: $name\n";
        $log->info("$jobid $name");
        $log->debug(join("\n", @$fileargs));

        #        print STDERR join("\n", @$fileargs), "\n";
        return $jobid;
    }

}    # _submit

sub _purge_ops {
    my %ops = @_;
    our @pbs_ops;
    foreach my $key (keys %ops) {
        foreach my $op (@pbs_ops) {
            delete $ops{$key} if $op =~ /^$key=/;
        }
    }
    return %ops;
}

1;
