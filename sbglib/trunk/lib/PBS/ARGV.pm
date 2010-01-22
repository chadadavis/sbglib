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


# Specify the command(s) to run yourself
# Will run: $0 some-other-argument $x, for each $x in @ARGV
my @jobids = qsub("$0 some-other-argument");

# With Getopt, give your PBS jobs the same options that you received
use Getopt::Long;
my %ops;
my $result = GetOptions(\%ops,'loglevel|l=s','logfile|f=s','debug|d:i');
# Add the dash back on to option names:
my @dashops = map { '-' . $_ => $ops{$_} } keys %ops;
my @jobids = qsub("$0 @dashops");

# Add any PBS directives as the elements of an array
my @jobids = qsub($0, '-M ae', '-N jobname', ...);

# PBS directives are not parsed, with the exception of:
# -N will be set to the currently processed argument, if not otherwise given
# -J (job arrays) will cause $PBS_ARRAY_INDEX to be appended to the command line
my @jobids = qsub($0, '-J 0-15');
# Will make the pbs job script run the command, for each $arg in @ARGV:
# myscript.pl $arg $PBS_ARRAY_INDEX
# And for each $arg, PBS will run with PBS_ARRAY_INDEX set to each of [0-15]


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


=head1 JOB ARRAYS



=head1 SEE ALSO

This module makes few assumptions about the particular kind of PBS system you
are running. For more fine-grained PBS job control, see L<PBS::Client> and
L<PBS::Status>.

=head1 METHODS

=cut

package PBS::ARGV;
use strict;
use warnings;
use 5.010;
use base qw/Exporter/;
our @EXPORT_OK = qw/qsub/;
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

 qsub($0, '-N myjobname', '-J 0-15', '-M ae');

=cut
sub qsub {
    my (%ops) = @_;

    # Already running in a PBS job, don't recurse
    if (defined $ENV{'PBS_ENVIRONMENT'}) {
        $log->debug('Running in PBS job');
        return;
    }
    
    return unless has_qsub();

    my @jobids;
    while (my $param = shift @::ARGV) {
        my $jobid = _submit($param, %ops);
        push @jobids, $jobid;
        # But don't consume it, if it failed to submit
        unshift @::ARGV, $param if $jobid eq '-1';
    }
    return @jobids;

} # qsub


# Do we have qsub on this system in the $PATH
sub has_qsub {
    our $_qsubpath;
    return $_qsubpath if defined $_qsubpath;
    foreach my $dir (File::Spec->path()) {
        my $f = File::Spec->catfile($dir, 'qsub');
        $_qsubpath = $f if(-e $f && -x $f );
    }
    $_qsubpath ||= '';
    $log->debug("_qsubpath: $_qsubpath");
    return $_qsubpath;

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
    # Add a dash to precede each argument name
    my @cmdops = map { '-' . $_ => $cmdops{$_} } keys %cmdops;
    $cmdline .= " @cmdops";

    # PBS directives
    my @directives = $ops{'directives'} ? @{$ops{'directives'}} : ();
    # Array? if -J directive given, also append \$PBS_ARRAY_INDEX to cmdline
    if (grep { /^-J/ } @directives) {
        $cmdline .= ' -J $PBS_ARRAY_INDEX';
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

    my ($tmpfh, $jobscript) = tempfile("pbs_XXXXX", TMPDIR=>1);
    print $tmpfh "#!/usr/bin/env sh\n";
    print $tmpfh "#PBS $_\n" for @directives;
    print $tmpfh "cd $ENV{PWD}\n";
    print $tmpfh "$cmdline\n";
    close $tmpfh;

    $log->debug("jobscript: $jobscript");
    my $jobid = `qsub $jobscript`;
    unless ($jobid) {
        my $msg = "Failed: qsub $jobscript";
        $log->error($msg);
        $File::Temp::KEEP_ALL = 1;
        return -1;
    } else {
        chomp $jobid;
        $log->info("$jobid $filearg");
        return $jobid;
    }

} # _submit


1;
