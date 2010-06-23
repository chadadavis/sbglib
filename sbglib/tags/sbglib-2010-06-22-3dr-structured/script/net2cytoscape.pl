#!/usr/bin/env perl


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


my %ops = getoptions(

    );

foreach my $file (@ARGV) {
    
    my $basename = basename($file,'.network');

    # Setup new log file specific to given input file
    SBG::U::Log::init($basename, %ops);

    # Load the Network object
    my $net;
    unless ($net = load_object($file)) {
        $log->error("$file is not an object");
        next;
    }
    _print_net($basename, $net);

}

exit;



# 
sub _print_net {
    my ($basename, $net) = @_;
    
    foreach my $interaction ($net->interactions) {
    	print "$interaction\n";
    }
}


