#!/usr/bin/env perl

=head1 NAME

B<fasta2net.pl> - Build structure-based interaction network for a complex

=head1 SYNOPSIS

fasta2net -top 20 -l INFO -maxid 75 -directives "-l cput=04:59:00" target-*.fa 

=head1 DESCRIPTION


=head1 SPECIFIC OPTIONS

=head2 -s | -searcher 'TransDBc'

Class name of the method to use for finding templates, must be in B<SBG::Search::> and must implement L<SBG::SearchI>. E.g.

 -searcher <TransDB|TransDBc|3DR|Bench|CSV|PairedBlast>

=head2 -m | -method B<standaloneblast> or B<remoteblast>

Default: standaloneblast

=head2 -x | -maxid Maximum sequence identity allowed for a template [0:100]

Mostly used for benchmarking, otherwise there is no reason to limit the identity

=head2 -n | -minid Minimum sequence identity allowed for a template [0:100]

Minimum sequence identity to consider, e.g.

 fasta2net -n 35 complex-xyz.fa

=head2 t|top Take the top N interface templates for any interacting pair.

To get no more than 20 inteface templates per interaction:

 fasta2net.pl -top 20 complex-xyz.fa
 
=head2 -v | -overlap Minimum fractional sequence coverage on a template

Default 0.5

=head2 -minsize 

Minimum size of a complex model, in number of components, e.g.

 -s 4 (4 or more component proteins in complex models

 -s 75% (at least 75% of the components in the network are modelled)

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

L<SBG::Network> , L<SBG::SearchI>

=cut


use strict;
use warnings;

use POSIX qw/ceil/;

# Send this off to PBS first, if possible, before loading other modules
use SBG::U::Run 
    qw/frac_of getoptions start_lock end_lock start_log @generic_options/;

# Options must be hard-coded, unfortunately, as local variables cannot be used
use PBS::ARGV @generic_options, 
    (
    'maxid|x=i',
    'minid|n=i',
    'networksize=i',
    'top|t=i',
    'method|m=s',
    'overlap|v=f',
    'searcher=s',
    'minsize|s=s',
    );

my %ops = getoptions @generic_options,
    (
    'maxid|x=i',
    'minid|n=i',
    'networksize=i',
    'top|t=i',
    'method|m=s',
    'overlap|v=f',
    'searcher=s',
    'minsize|s=s',
    );


use File::Basename;
use Moose::Autobox;
use Bio::SeqIO;
use Module::Load qw/load/;
use File::Spec::Functions;

# Local libraries
use FindBin qw/$Bin/;
use lib "$Bin/../lib/";
use Log::Any qw/$log/;

use SBG::Network;
use SBG::Search::TransDB;
use SBG::Search::PairedBlast;

use acaschema;
use SBG::U::DB; # qw/connect/;

# Searcher tries to find interaction templates (edges) to connect seq nodes
my $blast = SBG::Run::PairedBlast->new(database=>'pdbseq');
$ops{method} ||= 'standaloneblast';
$blast->method($ops{method});

$ops{searcher} ||= 'TransDBc';
$ops{searcher} =~ s/SBG::Search:://;
$ops{searcher} = 'SBG::Search::' . $ops{searcher};
eval { load $ops{searcher}; };
if ($@) {
    warn "Could not load search: $ops{searcher} :\n$@\n";
    exit;
}
my $buildops = {%ops}->hslice([qw/maxid minid cache top overlap/]);

# Use our own library, which does connection caching, to access the schema
my $schema = acaschema->connect(sub{SBG::U::DB::connect('aca')});

my $dir = basename($ENV{PWD});
# Strp off any preceeding date
my (undef, $explabel) = $dir =~ /(\d{4}-\d{2}-\d{2}-)?(.*)/;
# Lookup existing experiment, otherwise create a new one
my $exprec = $schema->resultset('Experiment')->find_or_create({label=>$explabel});

foreach my $file (@ARGV) {
    if (defined($ops{'J'})) {
        # The file is actually the Jth line of the list of files
        $file = PBS::ARGV::linen($file, $ops{'J'});
    }
    next unless $file;
    # Setup new log file specific to given input file
    my $targetid = basename($file,'.fa');
    
    mkdir $targetid;
    my $output = catfile($targetid, 'network');
    my $lock = start_lock($output);
    next if ! $lock && ! $ops{'debug'};
    start_log($output, %ops);

    # Add each sequence as a node to new network
    my $net = SBG::Network->new();
    # Cannot pass parameters to constructor, since Network is an ArrayRef
    $net->targetid($targetid);
    
    my $seqio = Bio::SeqIO->new(-file=>$file);
    while (my $seq = $seqio->next_seq) {
        $net->add_seq($seq);
    }

    my $ndomains = $net->nodes;
    $ops{minsize} = 2 unless defined $ops{minsize};
    $ops{minsize} = ceil frac_of($ops{minsize}, $ndomains);
    next if $ndomains < $ops{'minsize'};
    
    my $targetrec = $schema->resultset('Target')->create({
        label => $targetid,
        experiment_id => $exprec->id,
        ndomains => $ndomains,
    });

    # One searcher per target complex, to keep track of templates found
    my $searcher = $ops{searcher}->new(blast=>$blast);

    # Create interaction templates on the edges of the network
    $net = $net->build($searcher,%$buildops);

    my @partitions = $net->partition;

    for (my $i = 0, my $parti = 0; $i < @partitions; $i++) {
    	my $part = $partitions[$i];
    	next if $part->nodes < $ops{'minsize'};
        
        my $partlabel = sprintf "%02d", $parti;
        my $netrec = $schema->resultset('Network')->create({
    	   partition => $partlabel,
           nnodes => scalar($part->nodes),
    	   nedges => scalar($part->edges), 
    	   ninteractions => scalar($part->interactions),
    	   target_id => $targetrec->id,
    	});
    	
        # Pre-load the symmetry information
        $part->symmetry;
        # Save the primary key
        $part->id($netrec->id);
        $part->partid($partlabel);
        # TODO REFACTOR, shouldn't need to manually copy so much ...
        $part->targetid($net->targetid);

        my $dir = catdir($targetid, $partlabel);
        mkdir $dir;
        $output = catfile($dir, $partlabel . '.network');      
        $part->store($output);
        
        $parti++;      
    }
        
    end_lock($lock)
}





