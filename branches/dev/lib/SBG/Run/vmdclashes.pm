#!/usr/bin/env perl

=head1 NAME

SBG::Run::pdbc - Wrapper for running B<pdbc> (to get entry/chain descriptions


=head1 SYNOPSIS

 use SBG::Run::pdbc qw/pdbc/;

 my $dom = new SBG::DomainI(pdbid=>'2nn6', descriptor=>'A 13 _ to A 331 _');
 my %fields = pdbc($dom);
 print "Entry description:", $fields{header};
 print "Chain A description:", $fields{A};

=head1 DESCRIPTION

Depends on rlwrap and vmd

=head1 SEE ALSO

L<SBG::DomainI>

=cut

package SBG::Run::vmdclashes;
use strict;
use warnings;
use base qw/Exporter/;
our @EXPORT_OK = qw/vmdclashes/;

use Moose::Autobox;
use Log::Any qw/$log/;

use File::Basename qw/dirname/;
use Data::Dumper;

use SBG::ComplexIO::pdb;

=head2 vmdclashes

 Function: 
 Example : 
 Returns : Hash
 Args    : L<SBG::Complex>


Can process a path to a PDB file or an SBG::Complex object

=cut

sub vmdclashes {
    my ($thing) = @_;
    my $file;
    if ($thing->isa('SBG::Complex')) {
        my $io = SBG::ComplexIO::pdb->new(tempfile => 1);
        $io->write($thing);
        $io->close;
        $file = $io->file;
    }
    elsif (-r $thing) {
        $file = $thing;
    }
    else {
        $log->error("$thing is neither an SBG::Complex nor a readable file");
        return;
    }

    my $script = dirname(__FILE__) . '/../../../script/vmdclashes.tcl';
    my $cmd    = "vmd -dispdev none -e \"$script\" -args \"$file\"";
    $log->debug($cmd);
    my $res = {};
    open my $vmdfh,'-|', $cmd;
    while (<$vmdfh>) {
        next unless /=/;
        chomp;
        my ($key, $value) = split /=/;
        $res->{$key} = $value;
    }
    close $vmdfh;
    $log->debug(Dumper $res);
    return $res;

}    # vmdclashes

