#!/usr/bin/env perl

# Update this list with something like:
# grep  '^use ' --exclude='*.svn*' -r . |cut -f 2 -d ' '|cut -f 1 -d ';'|grep -v '^SBG'|sort|uniq
# Better: 
# perl -MDevel::Modlist=stop,nocore,cpan,zerodefault `find . -name '*.pl' -o -name '*.t' -o -name '*.pm' | xargs`

use inc::Module::Install;
use Module::AutoInstall;

name 'SBG';
all_from 'lib/SBG.pm';


requires 'Algorithm::Cluster' => '0';
requires 'Algorithm::Combinatorics' => '0';
requires 'Algorithm::Numerical::Sample' => '0';
requires 'autobox::List::Util' => '0';
requires 'Bio::DB::SwissProt' => '0';
requires 'Bio::Network::ProteinNet' => '0';
requires 'Bio::Seq' => '0';
requires 'Bio::Tools::Run::Alignment::Clustalw' => '0';
requires 'Bio::Tools::Run::RemoteBlast' => '0';
requires 'Bio::Tools::Run::StandAloneBlast' => '0';
requires 'Capture::Tiny' => '0';
requires 'CHI' => '0';
requires 'Class::MOP' => '0';
requires 'Clone' => '0';
requires 'Config::IniFiles' => '0';
requires 'Cwd' => '0';
requires 'Data::Dump' => '0';
requires 'Data::Dumper' => '0';
requires 'DBI' => '0';
requires 'File::NFSLock' => '0';
requires 'File::Slurp' => '0';
requires 'File::Spec' => '0';
requires 'File::Spec::Functions' => '0';
requires 'File::Temp' => '0';
requires 'Graph' => '0';
requires 'Graph::UnionFind' => '0';
requires 'Graph::Writer::GraphViz' => '0';
requires 'Hash::MoreUtils' => '0';
requires 'IO::Compress::Gzip' => '0';
requires 'IO::Uncompress::Gunzip' => '0';
requires 'IPC::Cmd' => '0';
requires 'List::MoreUtils' => '0';
requires 'List::Util' => '0';
requires 'Log::Any' => '0';
requires 'Log::Log4perl' => '0';
requires 'LWP::Simple' => '0';
requires 'Math::Round' => '0';
requires 'Math::Trig' => '1.10';
requires 'Module::AutoInstall' => '0';
requires 'Module::Load' => '0';
requires 'Moose' => '0';
requires 'Moose::Autobox' => '0';
requires 'Moose::Role' => '0';
requires 'Moose::Util::TypeConstraints' => '0';
requires 'Mouse' => '0';
requires 'namespace::autoclean' => 0; # Only for Qcons (TODO refactor)
requires 'PDL' => '0';
requires 'Scalar::Util' => '0';
requires 'Sort::Key' => '0';
requires 'Sort::Key::Top' => '0';
requires 'Statistics::Contingency' => '0';
requires 'Statistics::Lite' => '0';
requires 'Term::ReadKey' => '0';
#requires 'XML::XPath' => '0';

# TODO Only required for testing
requires 'Test::Class' => '0';
requires 'Test::More' => '0';
requires 'Test::Most' => '0';


# These STAMP binaries need to be found in the PATH
# STAMP also requires STAMPDIR to be set to the location of pdb.directories
requires_external_bin 'pdbc';
requires_external_bin 'pdbseq';
requires_external_bin 'stamp';
requires_external_bin 'transform';
requires_external_bin 'cofm';
requires_external_bin 'rasmol'; # by SBG::Run::rasmol
requires_external_bin 'blastpgp';
requires_external_bin 'clustalw';
requires_external_bin 'dot'; # graphviz
requires_external_bin 'vmd'; # SBG::Run::vmdclashes
requires_external_bin 'naccess';
requires_external_bin 'Qcontacts';

# Not available on CentOS
#requires_external_bin 'rlwrap'; # SBG::Run::vmdclashes (from vmd) 


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

