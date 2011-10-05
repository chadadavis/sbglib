#!/usr/bin/env perl

=head2 UPDATE

Update this list with

 make distclean
 files=`find . -name '*.pl' -o -name '*.t' -o -name '*.pm' | xargs`
 perl -d:Modlist=stop,nocore,cpan,zerodefault,stdout $files | \
     perl -lane 'next if /^SBG/;print "requires \"$F[0]\" => \"$F[1]\";"' >| \
     requires.txt

And then replace the 'requires' lines below with that 'requires.txt'

Note that certain modules like Bio::Network::Interaction and
Bio::Network::ProteinNet have an invalid version and have to be customized
manually.

=cut 

use inc::Module::Install;
use Module::AutoInstall;

name 'SBG';
# Collect metadata from the following module
all_from 'lib/SBG.pm';

requires "Algorithm::C3" => "0.08";
requires "Astro::FITS::Header" => "3.01";
#requires "Bio::Align::AlignI" => "-1,";
requires "Bio::Align::AlignI" => "0";
#requires "Bio::DB::RCSB" => "0";
requires "Bio::LocatableSeq" => "0";
#requires "Bio::Network::Interaction" => "1.0069";
requires "Bio::Network::Interaction" => "0";
requires "Bio::Network::Node" => "0";
#requires "Bio::Network::ProteinNet" => "1.0069";
requires "Bio::Network::ProteinNet" => "0";
requires "Bio::Tools::Run::Alignment::Clustalw" => "0";
requires "CHI" => "0.47";
requires "Class::C3" => "0.22";
requires "Class::C3::next" => "0";
requires "Class::MOP" => "2.0205";
requires "Class::MOP::Class::Immutable::Trait" => "2.0205";
requires "Clone" => "0.31";
requires "Compress::Raw::Zlib" => "2.033";
requires "Cwd" => "3.33";
requires "DBD::mysql" => "4.014";
requires "DBI" => "1.616";
requires "Data::Dump" => "1.19";
requires "Data::Dumper" => "2.128";
requires "Data::OptList" => "0.107";
requires "Devel::GlobalDestruction" => "0.04";
requires "Digest::MD5" => "2.51";
requires "Error" => "0.17016";
requires "Eval::Closure" => "0.06";
requires "Exporter" => "5.63";
requires "File::GlobMapper" => "1.000";
requires "File::Path" => "2.08";
requires "File::Slurp" => "9999.13";
requires "File::Temp" => "0.22";
requires "Graph" => "0.94";
#requires "Graph::Traversal::GreedyEdges" => "0";
requires "HTTP::Date" => "6.00";
requires "HTTP::Headers" => "6.00";
requires "IO" => "1.25";
requires "IO::String" => "1.08";
requires "LWP" => "6.02";
requires "List::MoreUtils" => "0.33";
requires "List::Util" => "1.23";
requires "Log::Any" => "0.14";
requires "MRO::Compat" => "0.11";
requires "Math::Complex" => "1.56";
requires "Module::Load" => "0.18";
requires "Moose::Autobox" => "0.11";
requires "Moose::Util::TypeConstraints" => "2.0205";
#requires "PDL" => "2.4.9_002";
requires "PDL" => "2.4.9";
requires "PDL::Bad" => "0";
requires "PDL::Config" => "0";
requires "PDL::IO::Misc" => "0";
requires "PDL::IO::Pnm" => "0";
requires "PDL::IO::Storable" => "0";
requires "PDL::ImageRGB" => "0";
#requires "PDL::Lite" => "2.4.9_002";
requires "PDL::Lite" => "2.4.9";
requires "PDL::Math" => "0";
requires "PDL::MatrixOps" => "0";
requires "PDL::Ops" => "0";
requires "PDL::Primitive" => "0";
requires "PDL::Slices" => "0";
requires "PDL::Ufunc" => "0";
#requires "PDL::Version" => "2.4.9_002";
requires "PDL::Version" => "2.4.9";
requires "Package::DeprecationManager" => "0.11";
requires "Package::Stash" => "0.32";
requires "Package::Stash::XS" => "0.25";
requires "Params::Util" => "1.04";
requires "Perl6::Junction" => "1.40000";
requires "Scope::Guard" => "0.20";
requires "Statistics::Lite" => "3.2";
requires "Storable" => "2.30";
requires "Sub::Exporter" => "0.982";
requires "Sub::Install" => "0.925";
requires "Sub::Name" => "0.05";
requires "Test::Builder" => "0.98";
requires "Time::Local" => "1.2000";
requires "Try::Tiny" => "0.11";
requires "URI" => "1.59";
requires "XSLoader" => "0.10";
requires "autobox" => "2.75";
requires "autobox::universal" => "0";
requires "base" => "2.14";
requires "mro" => "0";


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


