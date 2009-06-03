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

our @EXPORT_OK = qw(pdb2img);

use strict;
use warnings;

use File::Temp qw(tempfile tempdir);

use SBG::Log;
use SBG::Config qw/config/;

################################################################################


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

=cut
sub pdb2img {
    my (%o) = @_;
    $o{pdb} or return;
    $o{img} = $o{pdb} . '.ppm' unless $o{img};
    $logger->trace("$o{pdb} => $o{img}");
    my $rasmol = config()->val(qw/rasmol classic/) || 'rasmol';
    my $fh;
    my $cmd = "$rasmol -nodisplay >/dev/null";
#     my $cmd = "$rasmol -nodisplay ";
    $logger->trace($cmd);
    unless(open $fh, "| $cmd") {
        $logger->error("Failed: $cmd");
        return;
    }
    print $fh <<HERE;
load "$o{pdb}"
wireframe off
spacefill
color chain
HERE

    # Any additional options
    print $fh "$o{script}\n" if $o{script};

    print $fh <<HERE;
write "$o{img}"
exit
HERE

    # Need to explicitly close before checking for output file
    close $fh;
    unless (-s "$o{img}") {
        $logger->error("Rasmol failed to write: $o{img}");
        return;
    }
    return $o{img};
} # pdb2img
    

################################################################################
1;

__END__


