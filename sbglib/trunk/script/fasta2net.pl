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

=head2 o|output

=head2 t|top Take the top N interface templates for any interacting pair.

To get no more than 20 inteface templates per interaction:

 fasta2net.pl -top 20 complex-xyz.fa
 
=head2 -v | -overlap Minimum fractional sequence coverage on a template

Default 0.5


=head2 -s | -output


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

use File::Basename;
use Moose::Autobox;
use Bio::SeqIO;
use Module::Load qw/load/;

# Local libraries
use FindBin qw/$Bin/;
use lib "$Bin/../lib/";

use SBG::U::Run qw/frac_of getoptions start_lock end_lock start_log/;

use SBG::Network;
use SBG::Search::TransDB;
use SBG::Search::PairedBlast;

use PBS::ARGV qw/qsub/;

my %ops = getoptions 
    qw/maxid|x=i minid|n=i output|o=s top|t=i method|m=s overlap|v=f searcher=s/;


# Recreate command line options; (seems to work even with long option names)
my @jobids = qsub(throttle=>1000, blocksize=>$ops{'blocksize'}, options=>\%ops);

exit unless @ARGV;

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

foreach my $file (@ARGV) {
    if (defined($ops{'J'})) {
        # The file is actually the Jth line of the list of files
        $file = PBS::ARGV::linen($file, $ops{'J'});
    }

    # Setup new log file specific to given input file
    my $basename = basename($file,'.fa');
    my $lock = start_lock($basename);
    next if ! $lock && ! $ops{'debug'};
    start_log($basename, %ops);

    # Add each sequence as a node to new network
    my $net = SBG::Network->new();
    # Cannot pass parameters to constructor as Network is an ArrayRef
    $net->id($basename);
    
    my $seqio = Bio::SeqIO->new(-file=>$file);
    while (my $seq = $seqio->next_seq) {
        $net->add_seq($seq);
    }

    # One searcher per target complex, to keep track of templates found
    my $searcher = $ops{searcher}->new(blast=>$blast);

    # Create interaction templates on the edges of the network
    $net = $net->build($searcher,%$buildops);
    
    my $iaction_count = $net->edges > 1 ? $net->interactions : 0;
    
    if ($iaction_count) {
        # Pre-load the symmetry information
        $net->symmetry;
        my $base = $ops{output} || $basename;
        $net->store($base . '.network');
    }
    
    end_lock($lock, $iaction_count);

}


exit;





