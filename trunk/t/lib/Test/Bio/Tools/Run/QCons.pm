#!/usr/bin/env perl
package Test::Bio::Tools::Run::QCons;
use base qw/Test::SBG/;
use Test::SBG::Tools;

use Moose::Autobox;
use autobox::List::Util; 
use File::Which;

# startup failing will skip other tests
# Supposed to be true for 'setup' as well, but doesn't seem so
# However, $self is not defined for startup, only for setup
sub setup: Test(setup) {
    my ($self) = @_;
    # Setup the wrapper
    my $qcons = Bio::Tools::Run::QCons->new(
        file => $self->{test_data} . "/docking1.pdb",
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
