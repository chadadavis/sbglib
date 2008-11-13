#!/usr/bin/env perl

use strict;
use warnings;
use lib "../..";
use EMBL::Transform;
use EMBL::CofM;
use Data::Dumper;
use PDL::Matrix;
use Bio::Network::Node;
use EMBL::Node;
use Bio::Seq;
use EMBL::Seq;

my $transfile = 'test/2uzeA-2okrA-FoR.trans';

my $trans = new EMBL::Transform();

$trans->load($transfile);

print "trans:", $trans->{matrix}, "\n";

##################

# Get coords of 2uzeC
# my $c = new EMBL::CofM;
# $c->fetch('2uzeC');
my $c = new EMBL::CofM(0.364, -14.435, 41.266);

print "pt: $c\n";

# Transform 2uzeC using transformation from 2uzeA => 2okrA
# Put 2uzeC into 2okrA's frame of reference

print "Transforming...\n";
$c->transform($trans);

print "pt: $c\n";

my $src = new Bio::Network::Node(new Bio::Seq(-accession_number=>'1g3nC'));

    if (! defined $src->{ref}) {
#         $src->{ref} = new EMBL::Transform();

         $src->{_protein}{'refsdfdf'} = new EMBL::Transform();

#         $src->{ref}{dom} = $srcdom;
        print STDERR "\tInitial FoR: \n";
        # Do the same for the $dest, as it's in the same frame of reference
#         $dest->{ref} = new EMBL::Transform();
#         $dest->{ref}{dom} = $destdom;
#         return $success = 1;
    } else {
        print STDERR "\tSTAMP ...\n";
    }





