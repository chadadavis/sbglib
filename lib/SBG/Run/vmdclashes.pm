#!/usr/bin/env perl

=head1 NAME

SBG::Run::pdbc - Wrapper for running B<pdbc> (to get entry/chain descriptions


=head1 SYNOPSIS

 use SBG::Run::pdbc qw/pdbc/;

 my $dom = new SBG::DomainI(pdbid=>'2nn6', descriptor=>'A 13 _ to A 331 _');
 my %fields = pdbc($dom);
 print "Entry description:", $fields{'header'};
 print "Chain A description:", $fields{'A'};

=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::DomainI>

=cut



package SBG::Run::vmdclashes;
use base qw/Exporter/;
our @EXPORT = qw//;

use Moose::Autobox;
use Log::Any qw/$log/;

use File::Basename qw/dirname/;

use SBG::ComplexIO::pdb;


=head2 vmdclashes

 Function: 
 Example : 
 Returns : Hash
 Args    : L<SBG::Complex>


=cut
sub vmdclashes {
	my ($complex) = @_;
	my $io = SBG::ComplexIO::pdb->new(tempfile=>1);
	$io->write($complex);
	$io->close;
	my $file = $io->file;
	
    my $script = dirname(__FILE__) . '/../../../script/vmdclashes.tcl';
	my $cmd = "vmd -dispdev none -e $script -args $file";
    $log->debug($cmd);	
	my $res = {};
	open my $vmdfh, "$cmd |";
	while (<$vmdfh>) {
		next unless /=/;
		chomp;
		my ($key, $value) = split /=/;
		$res->{$key} = $value;
	}
	close $vmdfh;
	return $res;
	
} # vmdclashes

1;

