#!/usr/bin/env perl

package Test::Bio::DB::RCSB;

# Inheritance
use base qw/Test::SBG/;
use Test::SBG; 

use LWP::UserAgent;

sub setup : Test(setup) {
	my ($self) = @_;
	my $rcsb = Bio::DB::RCSB->new;
	$self->{rcsb} = $rcsb;
}


sub _rcsb : Test {
	my ($self) = @_;
	my $rcsb = $self->{rcsb};
	
	ok(defined $rcsb);
	isa($rcsb, 'Moose::Object');
}
	
sub _url : Test {
    my $self = shift;
    my $uri = "http://www.rcsb.org/pdb/rest/describePDB?structureId=4hhb";
    my $ua = LWP::UserAgent->new;
    my $req = HTTP::Request->new(GET => $uri);
    my $res = $ua->request($req);
    ok($res->is_success);
     
}
	
	
sub organism :Test {
	my $self = shift;
    my $id = '1g3n';
    my $rcsb = $self->{rcsb};
    my $organism = $rcsb->organism(structureId=>$id);
    is($organism, 'Homo sapiens');    
}



1;
