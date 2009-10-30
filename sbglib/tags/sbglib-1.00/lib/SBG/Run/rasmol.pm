#!/usr/bin/env perl

=head1 NAME

SBG::Run::rasmol - Rasmol utilities

=head1 SYNOPSIS

 use SBG::Run::rasmol;

=head1 DESCRIPTION


=head1 SEE ALSO


=cut

################################################################################

package SBG::Run::rasmol;
use base qw/Exporter/;

our @EXPORT = qw/rasmol/;
our @EXPORT_OK = qw/rasmol pdb2img/;

use strict;
use warnings;

use File::Temp qw(tempfile tempdir);

use SBG::U::Log qw/log/;
use SBG::U::Config qw/config/;
use SBG::DomainIO::pdb;
use SBG::U::List qw/flatten/;


################################################################################
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

    my $rasmol = config()->val(qw/rasmol executable/) || 'rasmol';
    my $io = new SBG::DomainIO::pdb(tempfile=>1);
    $io->write(@doms);
    my $cmd = "$rasmol " . $io->file;
    system("$cmd 2>/dev/null") == 0 or
        log()->error("Failed: $cmd\n\t$!");

    return $io->file;
} # rasmol



################################################################################
=head2 pdb2img

 Function:
 Example :
 Returns : 
 Args    :
          script - any additional options (string with newlines)
          pdb
          img

NB This does not seem to work with rasmol-gtk.  Use rasmol-classic, or just
rasmol. Set this in the C<config.ini>

Example script, highlight contacts with chain A:

 my $script = 
   "select *A\ncolor grey\nselect (!*A and within(10.0, *A))\ncolor HotPink";


=cut
sub pdb2img {
    my (%o) = @_;
    $o{pdb} or return;
    $o{img} = $o{pdb} . '.ppm' unless $o{img};
    $o{mode} ||= 'cartoon';

    log()->trace("$o{pdb} => $o{img}");
    my $rasmol = config()->val(qw/rasmol classic/) || 'rasmol';
    my $fh;
    my $cmd = "$rasmol -nodisplay >/dev/null 2>/dev/null";
    log()->trace($cmd);
    unless(open $fh, "| $cmd") {
        log()->error("Failed: $cmd\n\t$!");
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
        log()->error("Rasmol failed to write: $o{img}\n\t$!");
        return;
    }
    return $o{img};
} # pdb2img
    

################################################################################
1;

__END__

