#!/usr/bin/env perl

=head1 NAME

SBG::Run::naccess - Wrapper for running B<naccess> (solvent accessible surface)


=head1 SYNOPSIS


=head1 DESCRIPTION

=head1 SEE ALSO

L<SBG::DomainIO::pdb>

=cut


package SBG::Run::naccess;
use base qw/Exporter/;
our @EXPORT_OK = qw/sas_atoms buried/;

use Cwd;
use File::Basename;
use File::Spec;
use Log::Any qw/$log/;

# Belongs in own module
use PBS::ARGV qw/nlines linen/;

use SBG::DomainIO::pdb;
#use SBG::U::Cache qw/cache_get cache_set/;


our $cachename = 'sbgnaccess';



=head2 sas_atoms

 Function: 
 Example : my $sas = sas_atoms($sbgdomain1, $sbgdomain1, ...);
 Returns : Num: solvent accessible surface (Angstroms)
 Args    : Array or ArrayRef of L<SBG::DomainI>

If multiple Domains are provided, they are written to one PDB file and naccess is run on that PDB file. This provides the accessible surface of a complex.

TODO caching

=cut
sub sas_atoms {
    my $io = SBG::DomainIO::pdb->new(tempfile=>1, suffix=>'.pdb');
    $io->write(@_);
    $io->close;
    my $file = $io->file;

    my $pwd = getcwd();
    chdir File::Spec->tmpdir;
    
    my $cmd = "naccess $file";
    my $res = system("$cmd >/dev/null");
    if ($res) {
        $log->error("Failed: $cmd");
        chdir $pwd;
        return;
    }

    my $base = basename($file, '.pdb');
    my $rsa = $base . '.rsa';
    my $n = nlines($rsa);
    my $line = linen($rsa, $n-1);
    $line =~ /^TOTAL\s+(\S+)/;
    my $sas = $1;
    chdir $pwd;
    return unless $sas;
    return $sas;
    
} # sas_atoms


=head2 buried

Surface area buried by a protein-protein interface.

Not that the area calculated is the sum of the area of the buried interface in the first molecule plus the buried interface of the second molecule. If you want an estimate of the size of the interface itself, you might take the average of this number, i.e. divide it by two. The two halves of the interface are likely of similar size.
=cut
sub buried {
    my ($dom1, $dom2) = @_;

    my $sas1 = sas_atoms($dom1);
    my $sas2 = sas_atoms($dom2);
    my $sas_dimer = sas_atoms($dom1, $dom2);
    # Surface area of the two domains separately, minus that of the dimer
    # NB, this double counts what it at the interface
    my $buried_surface = ($sas1 + $sas2 - $sas_dimer);    
}


1;
