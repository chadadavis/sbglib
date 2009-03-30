#!/usr/bin/env perl

use Module::Build;
my $build = Module::Build->new
    (
     module_name => 'SBG::PA::Point',
     license  => 'perl',
     dist_abstract => 'abstract',
     requires => {
         'perl'          => '5.10.0',
         'Math::Round'  => '0.06',
#          'Other::Module' => '>= 1.2, != 1.5, < 2.0',
     },
    );
$build->create_build_script;

