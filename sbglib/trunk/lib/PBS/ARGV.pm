#!/usr/bin/env perl

=head1 NAME

PBS::ARGV

=head1 SYNOPSIS

A quick-and-dirty approach to parallelize a script that processes multiple input
files.

=head1 DESCRIPTION


=head1 SEE ALSO

L<PBS::Client>

=head1 METHODS

=cut

package PBS::ARGV;
use strict;
use warnings;
use base qw/Exporter/;
our @EXPORT_OK = qw/qsub/;
use vars qw($VERSION);
$VERSION = 0.01;

use Carp;
use File::Spec;
use File::Temp qw(tempfile);
use Log::Any qw/$log/;
use Getopt::Long;


################################################################################
=head2 qsub

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub qsub {
    my ($cmd, @directives) = @_;

    # Already running in a PBS job, don't recurse
    unless (defined $ENV{'PBS_ENVIRONMENT'}) {
        $log->debug('Running in PBS job');
        return;
    }
    
    return unless _findqsub();

    # Default: rerun same script
    $cmd ||= $0;
    $cmd = File::Spec->rel2abs($cmd);

    # Get options
    # TODO
    # $cmd .= "$_ " for @getoptions;

    my @jobids;
    while (my $param = shift @::ARGV) {
        push @jobids, _submit($cmd, $param, @directives);
    }
    
    return @jobids;

} # qsub

# Do we have qsub on this system in the $PATH
sub _findqsub {
    our $_qsubpath;
    return $_qsubpath if defined $_qsubpath;
    foreach my $dir (File::Spec->path()) {
        my $f = File::Spec->catfile($dir, 'qsub');
        $_qsubpath = $f if(-e $f && -x $f );
    }
    $_qsubpath ||= '';
    $log->debug("_qsubpath:$_qsubpath");
    return $_qsubpath;

}


sub _submit {
    my ($cmdline, $filearg, @directives) = @_;

    $cmdline .= " $filearg";
    # Array? if -J option given, append \$PBS_ARRAY_INDEX to cmd
    if (grep { /^-J/ } @directives) {
        $cmdline .= ' $PBS_ARRAY_INDEX';
    }
    # Add name, unless given
    push @directives, "-N $filearg" unless grep { /^-N/ } @directives;

    my ($tmpfh, $jobscript) = tempfile("pbs_XXXXX", TMPDIR=>1);
    print $tmpfh "#!/usr/bin/env sh\n";
    print $tmpfh "#PBS $_\n" for @directives;
    print $tmpfh "$cmdline\n";
    close $tmpfh;

    $log->debug("jobscript:$jobscript");
    my $jobid = `qsub $jobscript`;
    unless ($jobid) {
        my $msg = "Failed to qsub: $jobscript";
        carp "$msg\n";
        $log->error($msg);
        $File::Temp::KEEP_ALL = 1;
        return;
    } else {
        chomp $jobid;
        return $jobid;
    }

} # _submit

