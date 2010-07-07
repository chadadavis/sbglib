#!/usr/bin/env perl

# Update this list with something like:
# grep  '^use ' --exclude='*.svn*' -r . |cut -f 2 -d ' '|cut -f 1 -d ';'|grep -v '^SBG'|sort|uniq


use inc::Module::Install;
use Module::AutoInstall;

name 'SBG';
version '1.00';

requires 'autobox::List::Util' => '0';
requires 'Algorithm::Cluster' => '0';
requires 'Algorithm::Combinatorics' => '0';
requires 'B::Utils' => '0'; # required by B::Hooks::OP::Check
requires 'B::Hooks::OP::Check' => '0'; # required by Sub::Call::Recur
requires 'Bio::Network::Node' => '0';
requires 'Bio::Network::Interaction' => '0';
requires 'Bio::Tools::Run::Alignment::Clustalw' => '0';
requires 'Bio::Tools::Run::StandAloneBlast' => '0';
requires 'Carp::Assert' => 0; # required by CHI
requires 'CGI' => '0';
requires 'CHI' => '0';
requires 'Class::MOP' => '0';
requires 'Clone' => '0';
requires 'Config::IniFiles' => '0';
requires 'Data::Dump' => '0';
requires 'DBD::mysql' => '0';
requires 'DBI' => '0';
requires 'Devel::Symdump' => '0'; # Missing dep for Test::Pod::Coverage
requires 'File::Basename' => '0';
requires 'File::NFSLock' => '0';
requires 'File::Slurp' => '0';
requires 'File::Temp' => '0';
requires 'Getopt::Complete' => '0';
requires 'Graph' => '0.94';
requires 'Graph::Writer::GraphViz' => '0';
requires 'Hash::MoreUtils' => '0';
requires 'Heap::Priority' => '0';
requires 'Log::Any' => '0';
requires 'Log::Dispatch::File' => '0';
requires 'Log::Log4perl' => '0';
requires 'Math::Round' => '0';
requires 'Math::Trig' => '1.19';
requires 'Module::Load' => '0';
requires 'Moose' => '0.72';
requires 'Moose::Autobox' => '0';
requires 'Moose::Util::TypeConstraints' => '0';
requires 'MooseX::Role::Parameterized' => '0';
requires 'IO::Compress::Gzip' => '0';
requires 'IO::Uncompress::Gunzip' => '0';
requires 'PDL' => '2.4.4';
requires 'PDL::LinearAlgebra' => '0';
requires 'Sort::Key' => '0';
requires 'Sort::Key::Top' => '0';
requires 'Sub::Call::Recur' => '0';
requires 'Term::ReadKey' => '0';
requires 'Test::More' => '0';
requires 'Text::ParseWords' => '0';
requires 'Test::Pod::Coverage' => '1.08';


# These STAMP binaries need to be found in the PATH
# STAMP also requires STAMPDIR to be set to the location of pdb.directories
requires_external_bin 'pdbc';
requires_external_bin 'pdbseq';
requires_external_bin 'stamp';
requires_external_bin 'transform';
requires_external_bin 'cofm';
requires_external_bin 'rasmol';
requires_external_bin 'blastpgp';
requires_external_bin 'clustalw';
# requires_external_bin 'dot'; # graphviz

# Automagically install above deps from CPAN
#auto_install(force=>1); # Not compat with CPANPLUS
auto_install();

install_script 'script/fasta2net.pl';
install_script 'script/net2model.pl';
install_script 'script/sbgobj.pl';
install_script 'sbglib.sh';

# Test all *.t files, 
# Is there no 'recursive' option here?
WriteMakefile(
    test => {TESTS => 't/*.t t/*/*.t t/*/*/*.t t/*/*/*/*.t t/*/*/*/*/*.t'}
    );

