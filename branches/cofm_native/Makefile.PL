#!/usr/bin/env perl

=head2 UPDATE

Update this list with something like

 make distclean

 ack '^use '|perl -lne '($m)=/:use ([\w:]+)/;next unless $m=~/[A-Z]/;next if $m=~/^SBG/;$n{$m}=1;}{print "requires \"$_\" => \"0\";" for sort keys %n' \
 >| requires.txt

OR more sophisticated but with restrictive version numbers:

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


requires "Algorithm::Cluster" => "0";
requires "Algorithm::Combinatorics" => "0";
# In this distro
#requires "Bio::DB::RCSB" => "0";  
requires "Bio::Network::ProteinNet" => "0";
requires "Bio::Search::Hit::BlastHit" => "0";
requires "Bio::Seq" => "0";
# Not indexed by CPAN, use the distro file path to install in cpan
#requires "CJFIELDS/BioPerl-Run-1.006900.tar.gz" => undef;
requires "Bio::Tools::Run::Alignment::Clustalw" => "0";
requires "Bio::Tools::Run::StandAloneBlast" => "0";
requires "CGI" => "0";
requires "CHI" => "0";
requires "Carp" => "0";
requires "Class::MOP::Class" => "0";
requires "Clone" => "0";
requires "Cwd" => "0";
requires "DBI" => "0";
requires "Data::Dump" => "0";
requires "Data::Dumper" => "0";
requires "Digest::MD5" => "0";
requires "Fcntl" => "0";
requires "File::Basename" => "0";
requires "File::NFSLock" => "0";
requires "File::Slurp" => "0";
requires "File::Spec" => "0";
requires "File::Temp" => "0";
requires "Getopt::Complete" => "0";
requires "Getopt::Long" => "0";
requires "Graph" => "0";
requires "Graph::UnionFind" => "0";
requires "Graph::Writer::GraphViz" => "0.11";
requires "IO::Compress::Gzip" => "0";
requires "IO::File" => "0";
requires "IO::String" => "0";
requires "IO::Uncompress::Gunzip" => "0";
requires "IPC::Cmd" => "0";
requires "LWP::Simple" => "0";
requires "LWP::UserAgent" => "0";
requires "List::MoreUtils" => "0";
requires "List::Util" => "0";
requires "Log::Any" => "0";
requires "Log::Any::Adapter" => "0";
requires "Log::Log4perl" => "0";
# From SBG::U::Log
requires "Log::Dispatch::File" => "0";
requires "Math::Round" => "0";
requires "Math::Trig" => "0";
requires "Module::Load" => "0";
requires "Moose" => "0";
requires "Moose::Autobox" => "0";
requires "Moose::Role" => "0";
requires "Moose::Util::TypeConstraints" => "0";
requires "Net::Ping" => "0";
# In this distro
#requires "PBS::ARGV" => "0";  
requires "PDL" => "2.4.9_007";
requires "PDL::Basic" => "0";
requires "PDL::Core" => "0";
requires "PDL::IO::Misc" => "0";
requires "PDL::IO::Storable" => "0";
requires "PDL::Lite" => "0";
requires "PDL::Math" => "0";
requires "PDL::MatrixOps" => "0";
requires "PDL::NiceSlice" => "0";
requires "PDL::Primitive" => "0";
requires "PDL::Reduce" => "0";
requires "PDL::Transform" => "0";
requires "PDL::Ufunc" => "0";
requires "POSIX" => "0";
requires "Path::Class" => "0";
requires "Pod::Usage" => "0";
requires "Scalar::Util" => "0";
requires "Sort::Key" => "0";
requires "Sort::Key::Top" => "0";
requires "Statistics::Lite" => "0";
requires "Storable" => "0";
requires "Text::ParseWords" => "0";
requires "Tie::File" => "0";
requires "autobox::List::Util" => "0";

recommends "Bio::Tools::Run::QCons" => "0"; 
recommends "DBD::mysql" => "0"; 

# Required for testing
test_requires 'Test::Approx' => '0';
test_requires 'Test::Class' => '0';
test_requires 'Test::More' => '0';
test_requires 'Test::Most' => '0';
test_requires 'Data::Dumper' => '0';
test_requires 'Data::Dump' => '0';


# These STAMP binaries need to be found in the PATH
# http://code.google.com/p/bio-stamp/
requires_external_bin 'pdbc';       # SBG::Run::pdbc
requires_external_bin 'pdbseq';     # SBG::Run::pdbseq
requires_external_bin 'stamp';      # SBG::STAMP
requires_external_bin 'transform';  # SBG::DomainIO::stamp
requires_external_bin 'cofm';       # SBG::Run::cofm

# Rasmol required by SBG::Run::rasmol (only used by tests)
#requires_external_bin 'rasmol';    # SBG::Run::rasmol
requires_external_bin 'blastpgp';   # SBG::Run::Blast 
requires_external_bin 'clustalw';   # SBG::Complex SBG::Network
# dot and circo are part of GraphViz
#requires_external_bin 'dot';       # SBG::NetworkIO::dot
#requires_external_bin 'circo';     # SBG::NetworkIO::dot
#requires_external_bin 'naccess';   # SBG::Run::naccess

# Not available on CentOS
#requires_external_bin 'rlwrap';    # SBG::Run::vmdclashes
#requires_external_bin 'vmd';       # SBG::Run::vmdclashes


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


