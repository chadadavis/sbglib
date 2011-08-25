#!/usr/bin/env perl

=head1 NAME

SBG::Run::rasmol - Rasmol utilities

=head1 SYNOPSIS

 use SBG::Run::rasmol;

=head1 DESCRIPTION


=head1 SEE ALSO


=cut

package SBG::Run::rasmol;
use base qw/Exporter/;

our @EXPORT    = qw/rasmol/;
our @EXPORT_OK = qw/rasmol pdb2img/;

use strict;
use warnings;

use File::Temp qw(tempfile tempdir);
use Log::Any qw/$log/;

use Bio::Root::IO;    # exists_exe

use SBG::DomainIO::pdb;
use SBG::U::List qw/flatten/;

=head2 rasmol

 Function: Runs rasmol on given list of L<SBG::DomainI> objects
 Example : 
 Returns : Path to PDB file written to
 Args    : $doms, ArrayRef of L<SBG::DomainI> 


If no 'file' option is provided, a temporary file is created and returned

=cut

sub rasmol {
    my (@doms) = @_;
    @doms = SBG::U::List::flatten(@doms);

    my $rasmol_gui = Bio::Root::IO->exists_exe('rasmol-gtk')
        || Bio::Root::IO->exists_exe('rasmol')
        or return;

    my $io = new SBG::DomainIO::pdb(tempfile => 1);
    $io->write(@doms);
    my $cmd = "$rasmol_gui " . $io->file;
    system("$cmd 1>/dev/null 2>/dev/null") == 0
        or $log->error("Failed: $cmd\n\t$!");

    return $io->file;
}    # rasmol

=head2 pdb2img

 Function:
 Example :
 Returns : 
 Args    :
          script - any additional options (string with newlines)
          pdb
          img

NB This does not seem to work with rasmol-gtk.  Use rasmol-classic, or just
rasmol (if that is equivalent to rasmol-classic on your system). 

Example script, highlight contacts with chain A:

 my $script = 
   "select *A\ncolor grey\nselect (!*A and within(10.0, *A))\ncolor HotPink";


=cut

sub pdb2img {
    my (%o) = @_;
    $o{pdb} or return;
    $o{img} = $o{pdb} . '.ppm' unless $o{img};
    $o{mode} ||= 'cartoon';

    my $rasmol_converter = Bio::Root::IO->exists_exe('rasmol-classic')
        || Bio::Root::IO->exists_exe('rasmol')
        or return;
    $log->debug("$rasmol_converter: $o{pdb} => $o{img}");

    my $fh;
    my $cmd = "$rasmol_converter -nodisplay >/dev/null 2>/dev/null";
    $log->debug($cmd);
    unless (open $fh, "| $cmd") {
        $log->error("Failed: $cmd\n\t$!");
        return;
    }
    print $fh "load \"$o{pdb}\"\n";
    print $fh "color chain\n";
    print $fh "wireframe off\n";
    print $fh "$o{mode}\n";

    # Any additional options
    print $fh "$o{script}\n" if $o{script};

    print $fh <<HERE;
write "$o{img}"
exit
HERE

    # Need to explicitly close before checking for output file
    close $fh;
    unless (-s "$o{img}") {
        $log->error("$rasmol_converter failed to write: $o{img}\n\t$!");
        return;
    }
    return $o{img};
}    # pdb2img

1;

__END__


