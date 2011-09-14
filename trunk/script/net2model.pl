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

=head2 -target <some-complex.target>

Will load the structure in the given complex file and use it to benchmark the models generated.


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

# Local libraries
use FindBin qw/$Bin/;
use lib "$Bin/../lib/";

# Send this off to PBS first, if possible, before loading other modules
use SBG::U::Run qw/frac_of getoptions start_lock end_lock @generic_options/;

# Options must be hard-coded, unfortunately, as local variables cannot be used
use PBS::ARGV @generic_options,
    (
    'complete|c',     'overlap_thresh|o=f',
    'minsize|s=s',    'binsize|b=f',
    'clash_thresh=f', 'maxsolutions=i',
    'seed=s',         'target=s',
    'outputs=s',
    );

my %ops = getoptions @generic_options,
    (
    'complete|c',     'overlap_thresh|o=f',
    'minsize|s=s',    'binsize|b=f',
    'clash_thresh=f', 'maxsolutions=i',
    'seed=s',         'target=s',
    'outputs=s',
    );

use Moose::Autobox;
use POSIX qw/ceil/;
use File::Basename;
use Hash::MoreUtils qw/slice_def/;
use File::Spec::Functions;
use Log::Any qw/$log/;
use Carp;

use SBG::Role::Storable qw/retrieve/;
use SBG::U::Object qw/load_object/;
use SBG::U::Log;
use SBG::Complex;
use SBG::CA::Assembler2;
use Graph::Traversal::GreedyEdges;

use acaschema;
use SBG::U::DB;    # qw/connect dsn/;

# Use our own library, which does connection caching, to access the schema
my $dsn = SBG::U::DB::dsn(database => 'aca');
my $schema = acaschema->connect(sub { SBG::U::DB::connect($dsn) });

# Separate log file for each input
my $log_handle;
foreach my $file (@ARGV) {
    if (defined($ops{J})) {

        # The file is actually the Jth line of the list of files
        $file = PBS::ARGV::linen($file, $ops{J});
    }

    # Load the Network object
    my $net;
    unless ($net = load_object($file)) {
        warn("$file is not an object");
        next;
    }
    my $dir      = dirname $file;
    my $targetid = $net->targetid;
    my $partid   = $net->partid;
    my $destdir  = catdir($targetid, $partid);
    mkdir $destdir;
    my $output = catfile($targetid, $partid, 'model');
    my $lock = start_lock($output);
    next if !$lock && !$ops{debug};

    Log::Any::Adapter->remove($log_handle);

    # A log just for this input file:
    $log_handle = Log::Any::Adapter->set(
        '+SBG::Log',
        level => 'trace',
        file  => $output . '.log'
    );

    # A cheap way to track what crashes before finishing
    my $tryingfile = $output . '.trying';
    open my $tryingfh, '>', $tryingfile;
    close $tryingfh;

    _print_net($net);

    $ops{minsize} = 2 unless defined $ops{minsize};

    # Only full-size (complete coverage) models?
    $ops{minsize} = '100%' if $ops{complete};
    $ops{minsize} = ceil frac_of($ops{minsize}, scalar $net->nodes);

    # Traverse the network
    my $stats = _one_net($net, \%ops);
    print "\n";
    end_lock($lock, join("\t", @$stats));
    unlink $tryingfile;

}

exit;

#
sub _print_net {
    my ($net, $i, $n) = @_;
    $i ||= 1;
    $n ||= 1;
    my $str = sprintf
        "\n%-20s %4d nodes, %4d edges, %4d interactions \n",
        $net->targetid,
        scalar($net->vertices), scalar($net->edges),
        scalar($net->interactions);
    print "$str";
    $log->info($str);
}

# Assemble network
sub _one_net {
    my ($net, $ops) = @_;

    my %aops = slice_def($ops,
        qw/minsize binsize overlap_thresh maxsolutions clash_thresh/);

    my $assembler = SBG::CA::Assembler2->new(
        net      => $net,
        callback => \&_write_solution,
        %aops
    );
    if ($ops{seed} && -r $ops{seed}) {
        $assembler->seed(load_object $ops{seed});
    }
    if ($ops{target} && -r $ops{target}) {
        $assembler->target(load_object $ops{target});
    }
    my $t = Graph::Traversal::GreedyEdges->new(
        assembler => $assembler,
        net       => $net,         # TODO DEL should come from Assembler
    );

    # Go!
    $t->traverse();

    return $assembler->stats;
}

use Data::Dumper;

sub _write_solution {
    my ($complex, $class, $duplicate, $stats, $net) = @_;

    # Lookup record for this complex, or create it
    my $complex_table = $schema->resultset('Complex');
    my $complexrec    = $complex_table->search(
        { network_id => $net->id, model => $complex->modelid })->next;

    if ($complexrec) {

        # Already exists in DB, update with better scoring model
        $complexrec->score($complex->score);
        $complexrec->nreplaced($complexrec->nreplaced + 1);
        $complexrec->update;
    }
    else {
        $complex_table->create(
            {   network_id => $net->id,
                model      => $complex->modelid,
                score      => $complex->score,
            }
        );
    }

    my $targetid = $net->targetid;
    my $partid   = $net->partid;
    my $modelid  = $complex->modelid;
    my $destdir  = catdir($targetid, $partid, $modelid);
    mkdir $destdir;
    my $file = catfile($destdir, $complex->modelid . '.model');
    $complex->scores->put('mid', $complex->modelid);
    $complex->store($file);

    _status($stats);
}

sub _status {
    my ($stats) = @_;

    # Flush console and setup in-line printing, unless redirected
    if (-t STDOUT) {
        local $| = 1;
        print "\033[1K\r";    # Carriage return, i.e. w/o linefeed
                              # Print without newline
        print join("\t", @$stats), " ";
    }
}    # _status

