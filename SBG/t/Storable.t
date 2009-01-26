#!/usr/bin/env perl

use Test::More 'no_plan';

use File::Temp qw(tempfile);
use Storable;

use SBG::CofM;

# Things that should be Storable
use SBG::Root;
use SBG::Domain;
use SBG::Transform;
use SBG::Interaction;
use SBG::Complex;

my (undef, $path) = tempfile(UNLINK=>0);
my $orig;
my $retrieved;

readwrite(new SBG::Root());
my $dom3 = SBG::CofM::cofm('2nn6', 'CHAIN A');
my $dom4 = SBG::CofM::cofm('1g3n', 'CHAIN A');
readwrite($dom4);
my $dom5 = SBG::CofM::cofm('2br2', 'CHAIN A');
readwrite($dom5);
readwrite([$dom3,$dom4,$dom5,$dom3,$dom4,$dom5]);
readwrite(new SBG::Transform);
readwrite(new SBG::Interaction);
readwrite(new SBG::Complex);






################################################################################

sub readwrite {
    my ($obj, $path) = @_;
    (undef, $path) = tempfile() unless $path;
#     print Dumper $obj;
    store $obj, $path;
#     $obj->store($path);
    my $retrieved = retrieve $path;
    my $size = -s $path;
    is_deeply($obj, $retrieved, sprintf "store/retrieve on: %s (%s : %d bytes)",
              ref($obj), $path, $size);
    return $retrieved;
}



__END__
