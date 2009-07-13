#!/usr/bin/env perl

=head1 NAME

SBG::STAMP - Interface to Structural Alignment of Multiple Proteins (STAMP)

=head1 SYNOPSIS

 use SBG::STAMP;

=head1 DESCRIPTION

Only does pairwise superpositions at the moment.

=head1 SEE ALSO

L<SBG::DomainI> , L<SBG::Superposition> , <U::RMSD>

http://www.compbio.dundee.ac.uk/Software/Stamp/stamp.html

=cut

################################################################################

package SBG::STAMP;
use strict;
use warnings;
use base qw/Exporter/;

our @EXPORT_OK = qw/
superposition
/;

use File::Temp;

use SBG::DomainIO::stamp;
use SBG::Superposition;

use SBG::U::Config qw/config/;
use SBG::U::Log qw/log/;


################################################################################
=head2 superposition

 Function: Calculates superposition required to put $fromdom onto $ontodom
 Example :
 Returns : L<SBG::Superposition>
 Args    : 
           fromdom: L<SBG::DomainI>
           ontodom: L<SBG::DomainI>

Does not modify/transform B<$fromdom>

If a L<SBG::DomainI> already has a non-identity L<SBG::TransformI>, it is not
considered here. I.e. the transformation will be the one that places the native
orientation of B<$fromdom> onto the native orientation of B<$ontodom> .

=cut
sub superposition {
    my ($fromdom, $ontodom) = @_;
    if ($fromdom == $ontodom) {
        log()->trace("Identity: $fromdom");
        return SBG::Superposition::identity($fromdom);
    }
    log()->trace("$fromdom onto $ontodom");

    our $basecmd;
    $basecmd ||= _config();
    my ($fullcmd, $prefix) = _setup_input($basecmd, $ontodom, $fromdom);
    log()->trace("\n$fullcmd");
    system("$fullcmd > /dev/null");
    my $scanfile = "${prefix}.scan";
    my $fh;
    unless (-s $scanfile && open($fh, $scanfile)) {
        log()->error("Error running stamp:\n$fullcmd");
        return;
    }

    # Number of fits (residues?) that were performed
    my $minfit = config()->val('stamp', 'minfit') || 30;
    # Min Sc value to accept
    my $scancut = config()->val('stamp', 'scancut') || 2.0;
    
    my $superpos;
    while (<$fh>) {
        # Save only the fields, all separated by spaces
        next unless /^\# (Sc.*?)fit_pos/;
        # Cleanup key names
        my $line = $1;
        $line =~ s/=//g;
        # Read stats into hash        
        my %stats = split ' ', $line;
        # Is this the reference domain? Skip it;
        next if $stats{nfit} == 999 && $stats{n_equiv} == 999;

        # Skip if thresh too low
        return unless $stats{Sc} > $scancut && $stats{nfit} > $minfit;

        # Read in the domain being superposed onto the reference domain. This
        # will also contain the transformation.
        my $io = new SBG::DomainIO::stamp(fh=>$fh);
        my $dom = $io->read;
        
        # Create Superposition (the reference domain, $ontodom, hasn't changed)
        $superpos = new SBG::Superposition(%stats, to=>$ontodom, from=>$dom);
        last;
    }

    unlink $scanfile unless $File::Temp::KEEP_ALL;
    return $superpos;

} # superposition


# Write domains to temporary files and create output tempfile for STAMP
sub _setup_input {
    my ($basecmd, $probedom, @dbdoms) = @_;

    # Write probe domain to file
    my $ioprobe = new SBG::DomainIO::stamp(tempfile=>1);
    my $probefile = $ioprobe->file;
    $ioprobe->write($probedom);
    $ioprobe->close;

    # Write database domains to single file
    my $iodb = new SBG::DomainIO::stamp(tempfile=>1);
    my $dbfile = $iodb->file;
    foreach my $dom (@dbdoms) {
        $iodb->write($dom);
    }
    $iodb->close;

    # Setup tempfile for output. NB this goes out of scope and is deleted. But
    # we just need a random path prefix to pass on.
    my $prefix = File::Temp->new(TEMPLATE=>"scan_XXXXX", TMPDIR=>1)->filename;
    my $fullcmd = join(' ', 
                       $basecmd,
                       # probe (i.e. query) sequence
                       "-l $probefile",  
                       # database domains
                       "-d $dbfile",   
                       # tmp path to scan file (<prefix>.scan)
                       "-prefix", $prefix,
        );

    return ($fullcmd, $prefix)
} # _setup_input


# Default parameters for stamp
sub _config {

    # Get config setttings
    my $stamp = config()->val('stamp', 'executable') || 'stamp';
    # Number of fits (residues?) that were performed
    my $minfit = config()->val('stamp', 'minfit') || 30;
    # Min Sc value to accept
    my $scancut = config()->val('stamp', 'scancut') || 2.0;
    # Number of fits
    my $nfit = config()->val('stamp', 'nfit') || 2;
    # query slides every 5 AAs along DB sequence
    my $slide = config()->val('stamp', 'slide') || 5;

    my $stamp_pars = config()->val('stamp', 'params') || join(' ',
        '-s',           # scan mode: only query compared to each DB sequence
        '-secscreen F', # Do not perform initial secondary structure screen
        '-opd',         # one-per-domain: just one hit per query domain
        );

    $stamp_pars .= join(' ', ' ',
                        "-n $nfit",     
                        "-slide $slide",
                        "-minfit $minfit",
                        "-scancut $scancut", 
        );

    my $com = "$stamp $stamp_pars";
    log()->trace("\n$com");
    return $com;
} # _config


################################################################################
1;



