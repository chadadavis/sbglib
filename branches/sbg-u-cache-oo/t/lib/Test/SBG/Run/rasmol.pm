#!/usr/bin/env perl

package Test::SBG::Run::rasmol;
use base qw/Test::SBG/;
use Test::SBG;


sub setup : Test(setup) {
    my ($self) = @_;
    my $file = $self->{test_data} . "/pdb2nn6.ent";
    die "Not found: $file" unless -r $file;
    $self->{file} = $file;
}


sub pdb2img : Test {
    my ($self) = @_;
    my $file = $self->{file} or return;

    # Convert to IMG
    # And highlight close residues
    my $chain  = 'A';
    my $optstr = "select (!*$chain and within(10.0, *$chain))\ncolor white";
    my ( undef, $img ) = 
        File::Temp::tempfile( 'sbg_XXXXX', TMPDIR => 1, SUFFIX => '.ppm' );
    SBG::Run::rasmol::pdb2img( pdb => $file, script => $optstr, img => $img );
    
    
    ok( $img && -s $img, "pdb2img() $file => $img" );
    
}

1;
