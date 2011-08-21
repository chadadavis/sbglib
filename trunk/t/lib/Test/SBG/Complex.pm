#!/usr/bin/env perl
package Test::SBG::Complex;
use base 'Test::SBG';
use Test::SBG::Tools;

use SBG::U::Object qw(load_object);

sub setup : Test(setup) {
	my $self = shift;
	my $obj = load_object(file($self->{test_data}, "10.model"));
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
