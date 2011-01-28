#!/usr/bin/env perl

package Test::Bio::Tools::Run::QCons;

# Inheritance
use base qw/Test::SBG/;
# Just 'use' it to import all the testing functions and symbols 
use Test::SBG; 


use Moose::Autobox;
use autobox::List::Util; 

use Bio::Tools::Run::QCons;
use File::Which;

# startup failing will skip other tests
# Supposed to be true for 'setup' as well, but doesn't seem so
sub setup : Test(startup) {
    my ($self) = @_;
    # Setup the wrapper
    my $qcons = Bio::Tools::Run::QCons->new(
        file => "$Bin/SBG/data/docking1.pdb",
        chains => ['A', 'B'],
    );
    $self->{qcons} = $qcons;
    
    # But don't run, if it will fail, see if it's installed first
    my $binary = $qcons->program_name();
    my $path = which($binary);
    $self->{path} = $path;
}


sub residue_contacts : Test {
    my ($self) = @_;
    -x $self->{path} or return ": Qcontacts not installed";
    my $qcons = $self->{qcons};
    my $contacts = $qcons->residue_contacts;
    is($contacts->length, 288, 'residue_contacts()');
}


1;
