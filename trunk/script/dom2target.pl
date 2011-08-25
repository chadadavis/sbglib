#!/usr/bin/env perl

=head1 NAME

B<dom2target.pl> - Build a complex data structure from a STAMP domain spec

=head1 SYNOPSIS

dom2target.pl complex1.dom complex2.dom 

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

L<PBS::ARGV> , 

=cut

use strict;
use warnings;

# Local libraries
use FindBin qw/$Bin/;
use lib "$Bin/../lib/";

# Send this off to PBS first, if possible, before loading other modules
use SBG::U::Run qw/getoptions start_lock end_lock @generic_options/;
# Options must be hard-coded, unfortunately, as local variables cannot be used
use PBS::ARGV @generic_options, 
    ;
my %ops = getoptions @generic_options, 
    ;
    

use File::Basename;
use Moose::Autobox;

use Log::Any qw/$log/;
use Log::Any::Adapter;

use SBG::ComplexIO::stamp;


# Separate log file for each input
my $log_handle;
foreach my $file (@ARGV) {
    my $base = basename($file, '.dom');
    my $output = $base . '.target';
    next if -e $output . '.done';
    my $lock = start_lock($output);
    next if ! $lock && ! $ops{debug};

    Log::Any::Adapter->remove($log_handle);
      
    # A log just for this input file:
    $log_handle = Log::Any::Adapter->set(
        '+SBG::Log',level=>'trace',file=>$output . '.log');

    print $base, "\n" if -t STDOUT;
    my $io = SBG::ComplexIO::stamp->new(file=>$file);
    my $complex = $io->read;    

    $complex->store($output);
    my $ndoms = $complex->models->values->length;
    my $niactions = $complex->interactions->values->length;
    my $msg = join("\t",'Domains',$ndoms,'Interactions',$niactions);
    $log->info($msg);

    # TODO close log
    
    end_lock($lock, $msg);
    
}

