#!/usr/bin/env perl

=head1 NAME

B<net2model.pl> - Assemble components into complexes

=head1 SYNOPSIS

net2model.pl -minsize 50% -overlap_thresh .5 -maxsolutions 100 -binsize 3.0 -l INFO 
 -directives "-l cput=04:59:00" ../networks/*.network


=head1 DESCRIPTION



=head1 SPECIFIC OPTIONS


=head2 -c|omplete

Only produce complex models that contain every component of the network

=head2 -overlap_thresh Maximum fraction overlap before rejecting a clash

Default 0.5 (50%). Increase this to be more lenient with non-globular templates.

Applies when a new component is being added to a model

=head2 -clash_thresh Maximum percent atomic clashes tolerated in entire model

Default 2.0 (2%). Increase this to be more lenient with clashing loops.

Applies when a model is finished. I.e. this is final filtering and applies to all atoms in the final model, whereas overlap_thresh is just a quick check during model building that two globular domains are not roughly occupying the same space.

=head2 -minsize 

Minimum size of a complex model, in number of components, e.g.

 -s 4 (4 or more component proteins in complex models

 -s 75% (at least 75% of the components in the network are modelled)

=head2 -binsize

Bin size used by L<SBG::GeometricHash> to identify redundant models. Default 2.0

=head2 -maxsolutions

Maximum number of models to build per complex

=head2 -seed <some-model.model>

Will using the SBG::Complex in the model file as a starting point. Note that the network will need to include protein components with the same names. I.e. it will not (yet) add abitrary components to arbitrary structures. Rather a smaller subset of an interaction network can be built, with its corresponding complex modls. If one of these models forms a good basis, the larger interaction network can be built, and the time-consumig model builing in the larger interaction network will be reduced, as the seed complex will be the starting point and will not be disassembled.


=head1 GENERIC OPTIONS

=head2 -h | -help 

Print this help page

=head2 -l | -log <LOG-LEVEL>

Set logging level

In increasing order: TRACE DEBUG INFO WARN ERROR FATAL

I.e. setting B<-l WARN> (the default) will log warnings errors and fatal
messages, but no info or debug messages to the log file (B<log.log>)

=head2 -f | -file <Log file>

Default: <network name>.log in current directory

=head2 -blocksize <N>

Number of file arguments given on the command line to be processed by each PBS job. 

Default: 1

-blocksize 100 : every 100 files given on the command line will be processed in one synchronous PBS job. 

-blocksize 1 : every single input file is the input to a single PBS job


=head2 -J 

PBS array job

Identifies the only command line argument to a file from which to read the input files from. This is most useful when there are more files than can be written on the command line, as that is limited.

=head2 -directives "<directive1> <directive2> ..."

PBS directives to be passed to B<qsub>

E.g.

 -directives "-l cput=04:59:00"

Note that the directives must be quoted.

=head2 -d 1 | -debug 1

Set debug mode. 


=head2 -c 0 | -cache 0

Disable caching. On by default.



=head1 SEE ALSO

L<SBG::CA::Assembler2> , L<SBG::Network> , L<SBG::SearchI>

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
    'clash_thresh=f',
    'maxsolutions=i',
    'seed=s',
    );


# Try to submit to PBS, for each argument in @ARGV
# Recreate command line options;
my @jobids = qsub(throttle=>1000, blocksize=>$ops{'blocksize'}, options=>\%ops);
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
        slice_def($ops, 'minsize', 'binsize', 'overlap_thresh', 'maxsolutions', 'clash_thresh');

    my $assembler = SBG::CA::Assembler2->new(
        name=>$name, 
        net=>$net, 
        %aops);
    if ($ops{'seed'} && -r $ops{'seed'}) {
    	$assembler->seed(load_object $ops{'seed'});
    }
    my $t = Graph::Traversal::GreedyEdges->new(
        assembler=>$assembler,
        net=>$net, # TODO DEL should come from Assembler
        ); 

    # Go!
    $t->traverse();

    print "\n";
    print join "\t", $assembler->stats;
    print "\n";
    return $assembler->stats;
}




