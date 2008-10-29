#!/usr/bin/env perl

# POD documentation

=head1 NAME

EMBL::PBS - Quick PBS tools for the EMBL cluster(s)

=head1 SYNOPSIS

Give standard usage here

=head1 DESCRIPTION

Describe the object here

=head1 AUTHOR - Chad Davis <davis@embl.de>

=head1 CONTRIBUTORS

Additional contributors names and emails here

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package EMBL::PBS;

use strict;
use warnings;

use base qw(Exporter);
our @EXPORT = qw(
qsubarray
);

# CPAN
use File::Spec;
use File::Temp qw(tempfile);
use File::Basename;

use EMBL::File;


################################################################################

=head2 qsubarray

 Title   : qsubarray
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :
    input_file data file where each line represents the data input of one job
    process_script shell command to run on each line of input_file

The process_script can be any shell command. It will be given two command line
arguments: 1) The full path to input_file and 2) a line number (0-based)

See also: linei() of EMBL::File

Submit a file and script to process each separate line of the file. Each line of
the input file becomes one job, processed by the given script. The script will be
called with the name of the file and an index. The index identifies the line
number


=cut



sub qsubarray {
    my ($input_file, $process_script) = @_;
    return unless $input_file;
    # Rerun this same sript (with an index), if no alternative given
    $process_script ||= $0;

    # Absolutize paths
    $process_script = File::Spec->rel2abs($process_script);
    $input_file = File::Spec->rel2abs($input_file);
    my $name = basename($input_file);
    my ($tmpfh, $jobscript) = tempfile("tempjob_XXXXX");
    close $tmpfh;
    # Count number of inputs (numer of sub jobs, cluster needs to know this)
    my $last = nlines($input_file) - 1; 

# Write PBS array shell script (there will be just one of these)
open my $jobfh, ">$jobscript";

print $jobfh <<EOF;
#!/usr/bin/env sh
#PBS -N $name
#PBS -q clusterng\@pbs-master2
# This one pbs job script will be run $last+1 times (0-$last)
#PBS -J 0-${last}
# Mail me when it begins/ends
#PBS -M $ENV{'USER'}\@embl.de
#PBS -m abe 
# Won't take more than 60 seconds
# #PBS -l pcput=60
# #PBS -l walltime=60
# Run this script again, but with a sub-job ID, identifying the sequence to do
# This variable PBS_ARRAY_INDEX is provided by the PBS environment

$process_script $input_file \$PBS_ARRAY_INDEX

EOF

    close $jobfh;
    
    my $cmd = "qsub $jobscript";
    print STDERR "$cmd\n"; 
    my $job_arrary_id = `$cmd`;
    return $job_arrary_id;

}


=head2 cpus

 Title   : cpus
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub ncpus{
   my ($self,@args) = @_;


}

    
1;

