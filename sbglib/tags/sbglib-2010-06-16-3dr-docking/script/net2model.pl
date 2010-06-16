#!/usr/bin/env perl

=head1 NAME

B<assemble> - Assemble components into complexes

=head1 SYNOPSIS



=head1 DESCRIPTION


=head1 OPTIONS

=head2 -h|elp Print this help page

=head2 -l|og Set logging level

In increasing order: TRACE DEBUG INFO WARN ERROR FATAL

I.e. setting B<-l WARN> (the default) will log warnings errors and fatal
messages, but no info or debug messages to the log file (B<log.log>)

=head2 -f|ile Log file

Default: <network name>.log in current directory

=head2 -c|omplete

Only produce complex models that contain every component of the network

=head2 -s|ize

Minimum size of a complex model, in number of components, e.g.

 -s 4 (4 or more component proteins in complex models

 -s 75% (at least 75% of the components in the network are modelled)


=head1 SEE ALSO

L<SBG::CA::Assembler> , L<SBG::Network> , L<SBG::SearchI>

=cut



use strict;
use warnings;

use POSIX qw/ceil/;
use File::Basename;
use Hash::MoreUtils qw/slice_def/;
use File::Spec::Functions;
use Log::Any qw/$log/;
use Carp;

# Local libraries
use FindBin qw/$Bin/;
use lib "$Bin/../lib/";
use SBG::Role::Storable qw/retrieve/;
use SBG::U::Object qw/load_object/;
use SBG::U::Run qw/frac_of getoptions start_lock end_lock/;
use SBG::U::Log;
use SBG::Complex;
use SBG::CA::Assembler2;
use Graph::Traversal::GreedyEdges;
use PBS::ARGV qw/qsub/;





my %ops = getoptions(
    'complete|c',
    'overlap_thresh|o=f',
    'minsize|s=s', 
    'binsize|b=f', 
    'maxsolutions=i',
    );


# Try to submit to PBS, for each argument in @ARGV
# Recreate command line options;
my @jobids = qsub(options=>\%ops);
print "Submitted:\n", join("\n", @jobids), "\n", if @jobids;
# @ARGV is empty if all jobs could be submitted


foreach my $file (@ARGV) {
    if (defined($ops{'J'})) {
        # The file is actually the Jth line of the list of files
        $file = PBS::ARGV::linen($file, $ops{'J'});
    }

    my $basename = basename($file,'.network');
    my $outdir = $basename;
    $ops{'logdir'} = $outdir;
    my $basepath = catfile($outdir, $basename);
    mkdir $outdir;
    my $lock = start_lock($basepath);
    next if ! $lock && ! $ops{'debug'};

    # Setup new log file specific to given input file
    SBG::U::Log::init($basename, %ops);

    # Mark jobs that are tried, but not done, deleted when done
    open my $triedfile, "$basename.trying";
    close $triedfile;

    # Load the Network object
    my $net;
    unless ($net = load_object($file)) {
        $log->error("$file is not an object");
        next;
    }
    _print_net($basename, $net);

    $ops{minsize} = 3 unless defined $ops{minsize};
    # Only full-size (complete coverage) models?
    $ops{minsize} = '100%' if $ops{complete};
    $ops{minsize} = ceil frac_of($ops{minsize}, scalar $net->nodes);

    # Traverse the network
    my @stats = _one_net($net, $basename, \%ops);

#     my @modelfiles = <${outdir}/*.model>;
    end_lock($lock, join("\t", @stats));
    unlink $triedfile;

}

exit;



# 
sub _print_net {
    my ($basename, $net, $i, $n) = @_;
    $i ||= 1;
    $n ||= 1;
    my $str = sprintf
        "\n%-20s %4d nodes, %4d edges, %4d interactions \n",
        $basename,
        scalar($net->vertices), scalar($net->edges), 
        scalar($net->interactions);
    print "$str";
    $log->info($str);
}



# Assemble network
sub _one_net {
    my ($net,$name, $ops) = @_;

    my %aops = 
        slice_def($ops, 'minsize', 'binsize', 'overlap_thresh', 'maxsolutions');

    my $assembler = SBG::CA::Assembler2->new(
        name=>$name, 
        net=>$net, 
        %aops);
    my $t = Graph::Traversal::GreedyEdges->new(
        assembler=>$assembler,
        net=>$net,
        );

    # Go!
    $t->traverse();

    print "\n";
    print join "\t", $assembler->stats;
    print "\n";
    return $assembler->stats;
}




