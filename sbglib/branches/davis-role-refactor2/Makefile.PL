#!/usr/bin/env perl

use inc::Module::Install;
# use Module::Install::AutoInstall
# use Module::AutoInstall;

all_from => 'lib/SBG.pm';

requires 'Bio::Seq' => '1.006';
requires 'Bio::Network::Node' => '0'; 
requires 'Bio::Network::ProteinNet' => '0'; 
requires 'Config::IniFiles' => '0';
requires 'ExtUtils::F77' => '0'; # Required by PDL::Slatec
requires 'File::Basename' => '0'; 
requires 'File::Temp' => '0'; 
requires 'FindBin' => '0'; 
requires 'Getopt::Long' => '0'; 
requires 'Graph' => '0.86'; 
requires 'Graph::UnionFind' => '0'; 
requires 'Graph::Writer::GraphViz' => '0'; 
requires 'IO::String' => '0'; 
requires 'List::MoreUtils' => '0'; 
requires 'List::Util' => '0'; 
requires 'Log::Log4perl' => '0';
requires 'Log::Dispatch::File' => '0';
requires 'Math::Round' => '0'; 
requires 'Math::Trig' => '0'; 
requires 'Module::Build' => '0'; 
requires 'Module::Install' => '0'; # Ironically, no autoinstall of self
requires 'Module::Load' => '0'; 
requires 'Moose' => '0.72'; 
requires 'Moose::Autobox' => '0'; 
requires 'Moose::Role' => '0'; 
requires 'Moose::Util::TypeConstraints' => '0'; 
requires 'MooseX::StrictConstructor' => '0'; 
requires 'PDL' => '2.4.4';
requires 'PDL::Basic' => '0'; 
requires 'PDL::Core' => '0'; 
requires 'PDL::IO::Misc' => '0'; 
requires 'PDL::IO::Storable' => '0'; 
requires 'PDL::LinearAlgebra' => '0'; 
requires 'PDL::Lite' => '0'; 
requires 'PDL::Math' => '0'; 
requires 'PDL::Matrix' => '0'; 
requires 'PDL::MatrixOps' => '0'; 
requires 'PDL::NiceSlice' => '0'; 
requires 'PDL::Primitive' => '0'; 
requires 'PDL::Transform' => '0'; 
requires 'PDL::Ufunc' => '0'; 
requires 'Test::More' => '0'; 
requires 'Text::ParseWords' => '0'; 

# requires_external_bin 'stamp';
# requires_external_bin 'cofm';
# requires_external_bin 'pdbc';
# requires_external_bin 'dot';

# Automagically install above deps from CPAN
auto_install(force=>1);

# Test all *.t files, two levels deep
WriteMakefile(test => {TESTS => 't/*.t t/*/*.t t/*/*/*.t'});

