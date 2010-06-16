#!/usr/bin/env perl

=head1 NAME

B<sbgfa2net> - 

=head1 SYNOPSIS

sbgfa2net <fasta-sequences.fa>

=head1 DESCRIPTION


=head1 OPTIONS

=head2 -m|ethod B<standaloneblast> or B<remoteblast>

=head2 -h|elp Print this help page

=head2 -l|og Set logging level

In increasing order: TRACE DEBUG INFO WARN ERROR FATAL

I.e. setting B<-l WARN> (the default) will log warnings errors and fatal
messages, but no info or debug messages to the log file (B<log.log>)

=head2 -f|ile Log file

Default: <network name>.log in current directory


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
    qw/maxid|x=i minid|n=i output|o=s cache|c=i top|t=i method|m=s overlap|v=f searcher=s/;


# Recreate command line options; (seems to work even with long option names)
my @jobids = qsub(options=>\%ops);
print "Submitted:\n", join("\n", @jobids), "\n", if @jobids;

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
my $searcher = $ops{searcher}->new(blast=>$blast);
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
    my $net = SBG::Network->new;
    my $seqio = Bio::SeqIO->new(-file=>$file);
    while (my $seq = $seqio->next_seq) {
        $net->add_seq($seq);
    }

    # Create interaction templates on the edges of the network
    $net = $net->build($searcher,%$buildops);

    my $base = $ops{output} || $basename;
    my $iaction_count = $net->edges > 1 ? $net->interactions : 0;
    $net->store($base . '.network') if $iaction_count;

    end_lock($lock, $iaction_count);

}


exit;




