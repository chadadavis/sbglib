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

use Moose::Autobox;
use File::Temp;
use Cache::File;

use PDL::Lite;
use PDL::Core qw/pdl/;

use SBG::DomainIO::stamp;
use SBG::Superposition;
use SBG::Domain::Sphere;
use SBG::Run::cofm qw/cofm/;

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


The L<SBG::Transformation> contained in the L<SBG::Superposition> object returned is relative. I.e. it is not a cumulative transformation from the native B<$fromdom> to your B<$todom>, rather it is the transformation to the B<native> <$todom>. I.e. if your B<$from> already has a transformation, this will be relative  

If a L<SBG::DomainI> already has a non-identity L<SBG::TransformI>, it will also
be considered here. The Superposition returned contains a transformation that is
relative to any transformation already existing in B<fromdom>

=cut
sub superposition {
    my ($fromdom, $ontodom, $ops) = @_;
    if ($fromdom == $ontodom) {
        log()->trace("Identity: $fromdom");
        return SBG::Superposition::identity($fromdom);
    }
    log()->trace("$fromdom onto $ontodom");

    # Check cache
    my $superpos = _cache($fromdom, $ontodom);
    if ($superpos) {
        # Negative cache? (i.e. superpostion previously found not possible)
        return if ref($superpos) eq 'ARRAY';
        # Cache hit
        return $superpos;
    }

    our $basecmd;
    $basecmd ||= _config();
    my ($fullcmd, $prefix) = _setup_input($basecmd, $ontodom, $fromdom);
    $fullcmd .= " $ops" if $ops;
    log()->trace("\n$fullcmd");
    system("$fullcmd > /dev/null");
    my $scanfile = "${prefix}.scan";
    my $fh;
    unless (-s $scanfile && open($fh, $scanfile)) {
        log()->error("Error running stamp:\n$fullcmd");
        # Negative cache
        _cache($fromdom, $ontodom, []);
        return;
    }

    # Number of fits (residues?) that were performed
    my $minfit = config()->val('stamp', 'minfit') || 30;
    # Min Sc value to accept
    my $scancut = config()->val('stamp', 'scancut') || 2.0;
    
    while (my $_ = <$fh>) {
        # Save only the fields, all separated by spaces
        next unless /^\# (Sc.*?)fit_pos/;
        # Cleanup key names
        my $line = $1;
        $line =~ s/=//g;
        # Read stats into hash        
        my %stats = split ' ', $line;
        # Is this the reference domain? Skip it;
        # NB these are the same results if STAMP performed no fits
        next if $stats{nfit} == 999 && $stats{n_equiv} == 999;

        # Skip if thresh too low
        if ($stats{Sc} < $scancut || $stats{nfit} < $minfit) {
            _cache($fromdom, $ontodom, []);
            return;
        }

        # Read in the domain being superposed onto the reference domain. This
        # will also contain the (cumulative) transformation.
        my $io = new SBG::DomainIO::stamp(fh=>$fh);
        my $dom = $io->read;
        # Transformation relative to input transform
        my $reltrans = 
            $dom->transformation->relativeto($fromdom->transformation);
        # Make this the transformation that we return in the Superposition
        $dom->transformation($reltrans);

        # Create Superposition (the reference domain, $ontodom, hasn't changed)
        $superpos = new SBG::Superposition(
            to=>$ontodom, from=>$dom, scores=>{%stats} );
        last;
    }

    unlink $scanfile unless $File::Temp::KEEP_ALL;
    _cache($fromdom, $ontodom, $superpos);
    return $superpos;

} # superposition


################################################################################
=head2 _cache

 Function: 
 Example : 
 Returns : Re-retrieved object from cache
 Args    : [] implies negative caching

Cache claims to even work between concurrent processes!

=cut
sub _cache {
    my ($from, $to, $data) = @_;
    # Don't cache transformed domains
    return if 
        $from->transformation->has_matrix || $to->transformation->has_matrix;

    our $cache;
    $cache ||= new Cache::File(
        cache_root => ($ENV{TMPDIR} || '/tmp') . '/sbgsuperposition');
    my $key = "${from}--${to}";
    my $entry = $cache->entry($key);

    if (defined $data) {

        $entry->freeze($data);

        # Also cache the inverse superposition (NB [] means negative cache)
        my $ikey = "${to}--${from}";
        my $ientry = $cache->entry($ikey);
        my $idata;
        if (ref($data) eq 'ARRAY') {
            log()->trace("Caching (negative) $key and $ikey");
        } else {
            $idata = $data->inverse;
            log()->trace("Caching $key and $ikey");
        }
        $ientry->freeze($idata);
        log()->trace("Caching $key and $ikey");
    }

    log()->debug("Cache " . ($entry->exists ? 'hit' : 'miss') . " $key");

    # If it was just cached, it's now there, this serves as confirmation too
    $data = $entry->thaw;
    return $data;

} # _cache


################################################################################
=head2 irmsd

 Function: 
 Example : 
 Returns : 
 Args    : 

    # TODO BUG What if transformations already present
    # And what if they're from different PDB IDs (same question)

=cut
sub irmsd {
    my ($doms1, $doms2) = @_;

    # NB these superpositions are unidirectional (always from 1 to 2)
    # Only difference, relative to A or B component of interaction
    my $supera = superposition($doms1->[0], $doms2->[0]);
    my $superb = superposition($doms1->[1], $doms2->[1]);

    # Define crosshairs, in frame of reference of doms1 only
    my $coordsa = _irmsd_rel($doms1, $supera);
    my $coordsb = _irmsd_rel($doms1, $superb);
    
    # RMSD between two sets of 14 points (two crosshairs) each
    my $irmsd = SBG::U::RMSD::rmsd($coordsa, $coordsb);

} # irmsd


# Get coordinates of reference domains relative to given transformation
sub _irmsd_rel {
    my ($origdoms, $superp) = @_;

    my $spheres = $origdoms->map(sub{SBG::Run::cofm::cofm($_)});

    # Apply superposition to each of the domains
    $spheres->map(sub{$superp->apply($_)});

    # Coordinates of two crosshairs using transformation 
    # TODO DES clump needs to be in a DomSetI
    my $coords = $spheres->map(sub{$_->coords});
    # Convert to single matrix
    $coords = pdl($coords)->clump(1,2);

    return $coords;
}


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
                       # tmp path to scan file ( <prefix>.scan )
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



