#!/usr/bin/env perl

use PBS::ARGV qw/qsub/;

use File::Temp;
use SBG::U::Log qw/log/;
use Log::Any qw/$log/;
use Log::Any::Adapter;
use Getopt::Long;



my %ops;
my $result = GetOptions(\%ops,
                        'help|h',
                        'loglevel|l=s',
                        'logfile|f=s', 
                        'debug|d:i',
    );                  

$ops{debug} = 1 if defined $ops{debug};
$ops{loglevel} = 'TRACE' if ($ops{debug} && ! $ops{loglevel});
SBG::U::Log::init($ops{loglevel}) if $ops{loglevel};
$File::Temp::KEEP_ALL = $ops{debug};
Log::Any::Adapter->set('+SBG::U::Log');

# Recreate command line options;
my @dashops = map { '-' . $_ => $ops{$_} } keys %ops;
$log->debug("dashops:@dashops");
my @jobids = qsub("$0 @dashops", '-M ae');
print STDOUT "Submitted jobs: \n", join("\n",@jobids), "\n";

$log->debug("ARGV:@ARGV");

foreach (@ARGV) {
    print "Got '$_' with '", join(' ', %ops), "',with HOME=$ENV{HOME} on ", `hostname`;
}
