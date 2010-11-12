#!/usr/bin/env perl

package Test::SBG::Complex;

# Inheritance
use base qw/Test::SBG/;
# Just 'use' it to import all the testing functions and symbols 
use Test::SBG; 
use SBG::U::Object qw/load_object/;
use Moose::Autobox;

sub setup : Test(setup) {
	my $self = shift;
	my $obj = load_object(catfile($self->{test_data}, "10.model"));
	$self->{obj} = $obj;
}


sub chain_of : Test {
	my $self = shift;
	my $obj = $self->{obj};
	my $last_model = $obj->all_models->last;
    # 22 chains?	
	is($obj->chain_of(model=>$last_model), 'V');
	
}

1;
