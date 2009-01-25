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

my (undef, $path) = tempfile();
my $orig;
my $retrieved;

readwrite(new SBG::Root());
readwrite(new SBG::Domain());
my $dom5 = SBG::CofM::cofm('2br2', 'CHAIN A');
readwrite($dom5);
readwrite(new SBG::Transform);
readwrite(new SBG::Interaction);
readwrite(new SBG::Complex);






################################################################################

sub readwrite {
    my ($obj, $path) = @_;
    (undef, $path) = tempfile() unless $path;
#     print Dumper $obj;
#     store $obj, $path;
    $obj->store($path);
    my $retrieved = retrieve $path;
    my $size = -s $path;
    is_deeply($obj, $retrieved, sprintf "store/retrieve on: %s (%s : %d bytes)",
              ref($obj), $path, $size);
    return $retrieved;
}



__END__
