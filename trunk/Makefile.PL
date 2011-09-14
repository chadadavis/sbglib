#!/usr/bin/env perl

=head2 UPDATE

Update this list with

  files=`find . -name '*.pl' -o -name '*.t' -o -name '*.pm' | xargs`
  perl -d:Modlist=stop,nocore,cpan,zerodefault $files

=cut 

use inc::Module::Install;
use Module::AutoInstall;

name 'SBG';
# Collect metadata from the following module
all_from 'lib/SBG.pm';


requires 'autodie' => '0'; # Qcons
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
requires 'IO::Prompt' => '0';
requires 'IO::Uncompress::Gunzip' => '0';
requires 'IPC::Cmd' => '0';
requires 'List::MoreUtils' => '0';
requires 'List::Util' => '0';
requires 'Log::Any' => '0';
requires 'Log::Any::Adapter' => '0';
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


# Only required for testing
test_requires 'Test::Approx' => '0';
test_requires 'Test::Class' => '0';
test_requires 'Test::More' => '0';
test_requires 'Test::Most' => '0';


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
requires_external_bin 'naccess';
requires_external_bin 'Qcontacts';


# Not available on CentOS
#requires_external_bin 'rlwrap'; # SBG::Run::vmdclashes (from vmd) 
#requires_external_bin 'vmd'; # SBG::Run::vmdclashes


# install_script glob('script/*.pl');
install_script 'script/fasta2net.pl';
install_script 'script/net2model.pl';
install_script 'script/sbgobj.pl';
install_script 'sbglib.sh';

# Automagically install above deps from CPAN
auto_install();


# If we used Test::Class everywhere, this would be sufficient
# WriteAll;

# And if you don't need a "Pure Perl" solution, this is sufficient:
# WriteMakefile(test => {TESTS => `find t -name '*.t' | xargs` });

# But instead do recursive search for ./t/*.t files
use File::Find;
my @tests;
find(sub { push @tests, $File::Find::name if /\.t$/ }, 't');

WriteMakefile(test => { TESTS => "@tests" });


