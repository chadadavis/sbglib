#!/usr/bin/env perl

=head1 NAME

=cut



use strict;
use warnings;

use File::Basename;
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

use SBG::NetworkIO::sif;

my %ops = getoptions(
    );

# STDOUT by default
my $io = SBG::NetworkIO::sif->new();

foreach my $file (@ARGV) {

    my $basename = basename($file,'.network');

    # Load the Network object
    my $net;
    unless ($net = load_object($file)) {
        $log->error("$file is not an object");
        next;
    }
    $io->write($net);
    
}

exit;

