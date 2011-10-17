#!/usr/bin/env perl

=head1 NAME

SBG::Run::naccess - Wrapper for running B<naccess> (solvent accessible surface)


=head1 SYNOPSIS


=head1 DESCRIPTION

=head1 SEE ALSO

L<SBG::DomainIO::pdb>

=cut

package SBG::Run::naccess;
use strict;
use warnings;
use base qw/Exporter/;
our @EXPORT_OK = qw/sas_atoms buried/;

use Cwd;
use File::Basename;
use File::Spec;
use Log::Any qw/$log/;
use Moose::Autobox;
use Tie::File;

use SBG::U::List qw/flatten/;

use SBG::DomainIO::pdb;


=head2 sas_atoms

 Function: 
 Example : my $sas = sas_atoms($sbgdomain1, $sbgdomain1, ...);
 Returns : Num: solvent accessible surface (Angstroms)
 Args    : Array or ArrayRef of L<SBG::DomainI>

If multiple Domains are provided, they are written to one PDB file and naccess is run on that PDB file. This provides the accessible surface of a complex.

TODO caching

=cut

sub sas_atoms {
    my @doms = flatten(@_);
    $log->debug(scalar(@doms), " domains: @doms");
    my $io = SBG::DomainIO::pdb->new(tempfile => 1, suffix => '.pdb');
    $io->write(@doms);
    $io->close;
    my $file = $io->file;

    my $pwd = getcwd();
    chdir File::Spec->tmpdir;

    my $cmd = "naccess $file";
    $log->debug($cmd);
    my $res = system("$cmd >/dev/null");
    chdir $pwd;
    my $rsa = $file;
    $rsa =~ s/\.pdb$/.rsa/;
    unless (-r $rsa && -s $rsa) {
        $log->error("Cannot read RSA file: $rsa");
        return;
    }
    my @lines;
    tie @lines, 'Tie::File', $rsa;
    my $line = $lines[-1];
    my $sas;
    if ($line =~ /^TOTAL\s+(\S+)/) {
        $sas = $1;
        $log->debug("@doms $sas");
    }
    return unless $sas;
    return $sas;

}    # sas_atoms

=head2 buried

Surface area buried by a protein-protein interface.

As a percent [0:100]

The area calculated is the sum of the solvent-accessibel surface of the individual domains, minus the solvent-accessible surface of the complex as a whole.

=cut

sub buried {
    my $doms = flatten(@_);

    $log->debug($doms->length, " domains in complex");

    # Each domain individually, i.e. no contacts to partners are seen
    # TODO BUG strangest bug I've ever seen:
    # without flatten_deep() sets each array element to undef, after
    # successfully calling sas_atoms. Values are correct, inputs are erased.
    # flatten_deep works around this, presumably via an intermediate copy ...
    my $surfaces = $doms->flatten_deep->map(sub { sas_atoms($_) });

    $surfaces = $surfaces->grep(sub {defined});
    $log->debug($surfaces->length, " surfaces computed");
    return unless $surfaces->length == $doms->length;
    my $sum = $surfaces->sum;
    $log->debug("Sum $sum");

    # Minus the solvent-acessible surface of the complex as a whole
    my $complex_sas = sas_atoms($doms) or return;
    $log->debug("Complexed $complex_sas");
    my $buried = $sum - $complex_sas;
    $log->debug("Buried $buried");
    return 100.0 * $buried / $complex_sas;
}

1;
