#!/usr/bin/env perl

# Update this list with something like:
# cd sbglib
# grep  '^use ' --exclude='*.svn*' -r . |cut -f 2 -d ' '|cut -f 1 -d ';'|grep -v '^SBG'|sort|uniq


use inc::Module::Install;
# use Module::Install::AutoInstall
# use Module::AutoInstall;

all_from => 'lib/SBG.pm';

requires 'Bio::Tools::Run::StandAloneBlast' => '1.006001';
requires 'Cache' => '0';
requires 'CGI' => '0';
requires 'Class::MOP' => '0';
requires 'Clone' => '0';
requires 'Config::IniFiles' => '0';
requires 'Data::Dump' => '0';
requires 'File::Basename' => '0';
requires 'File::Temp' => '0';
requires 'Graph' => '0.86';
requires 'Graph::Writer::GraphViz' => '0';
requires 'Log::Log4perl' => '0';
requires 'Math::Round' => '0';
requires 'Math::Trig' => '1.19';
requires 'Module::Load' => '0';
requires 'Moose' => '0.72';
requires 'Moose::Autobox' => '0';
requires 'Moose::Util::TypeConstraints' => '0';
requires 'MooseX::Role::Parameterized' => '0';
requires 'PDL' => '2.4.4';
requires 'PDL::LinearAlgebra' => '0';
requires 'Test::More' => '0';
requires 'Text::ParseWords' => '0';


# These STAMP binaries need to be found in the PATH
# STAMP also requires STAMPDIR to be set to the location of pdb.directories
requires_external_bin 'cofm';
# requires_external_bin 'dot';
requires_external_bin 'pdbc';
# requires_external_bin 'pdbseq';
requires_external_bin 'stamp';
requires_external_bin 'transform';


requires_external_bin 'rasmol';

# Automagically install above deps from CPAN
#auto_install(force=>1); # Not compat with CPANPLUS
auto_install();

# Test all *.t files, up to two levels deep
WriteMakefile(test => {TESTS => 't/*.t t/*/*.t t/*/*/*.t'});

