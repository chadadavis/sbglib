#!/usr/bin/env perl

use PBS::ARGV qw/qsub/;

use File::Temp;
$File::Temp::KEEP_ALL = 1;

@jobids = qsub($0, '-M ae');

print STDERR "@jobids\n";

use Getopt::Long;
my %ops;
my $result = GetOptions(\%ops,
                        'h|help',
                        'l|loglevel=s',
                        'f|logfile=s', 
                        'd|debug',
                        'maxid|x=i',
                        'minid|n=i',
                        'output|o=s',
                        'cache|c=i',
    );                  




foreach (@ARGV) {
    print "Got $_ on ", `hostname`;
}
