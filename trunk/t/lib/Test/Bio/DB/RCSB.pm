#!/usr/bin/env perl
package Test::Bio::DB::RCSB;
use base qw/Test::SBG/;
use Test::SBG::Tools;

use LWP::UserAgent;

# Any 'setup' is run once before every other test.
# You can put any code in here.
# I'm using it to create a fresh object each time
# I save that object, over-writing any previous object
sub setup : Test(setup) {
    my ($self) = @_;
    my $rcsb = Bio::DB::RCSB->new;
    $self->{rcsb} = $rcsb;
}

# Now each of the following tests are completely independent. 

sub _rcsb : Test {
    my ($self) = @_;
    my $rcsb = $self->{rcsb};

    ok(defined $rcsb);
    isa($rcsb, 'Moose::Object');
}

sub _url : Test {
    my $self = shift;
    my $uri  = "http://www.rcsb.org/pdb/rest/describePDB?structureId=4hhb";
    my $ua   = LWP::UserAgent->new;
    my $req  = HTTP::Request->new(GET => $uri);
    my $res  = $ua->request($req);
    ok($res->is_success);

}

sub organism : Test {
    my $self     = shift;
    my $rcsb     = $self->{rcsb};
    my $id       = '4hhb';
    my $organism = $rcsb->organism(structureId => $id);

    # Use 'like' because it may be suffixed with common name, e.g. ' (man)'
    like($organism, qr/^Homo sapiens/);
}

sub multiple_organisms : Tests {
    local $TODO = "Find an entry with multiple organisms";
}

1;
