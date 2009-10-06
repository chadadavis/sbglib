#!/usr/bin/env perl

=head1 NAME

SBG::STAMP - Interface to Structural Alignment of Multiple Proteins (STAMP)

=head1 SYNOPSIS

 use SBG::STAMP;

=head1 DESCRIPTION

Only does pairwise superpositions at the moment.

The B<stamp> binary must exist in you B<PATH>.

NB this should not be /g/russell1/lbin/stamp

See http://www.russell.embl.de/private/wiki/index.php/STAMP#Bugs

Additionally STAMP requires the variable B<STAMPDIR> to be set to its B<defs>
subdirectory, where it stores its data files. This might look something like
this:

 export STAMPDIR=/usr/local/stamp.4.3/defs
 export PATH=$PATH:$STAMPDIR/../bin/linux



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
use SBG::U::Log qw/log/;


# TODO DES need to be set in a Run object

# STAMP binary (add full path, unless present in shell's PATH)
# our $stamp = '/g/russell1/lbin/stamp';
# our $stamp = '/usr/local/stamp.4.3/bin/stamp';
# our $stamp = '/usr/local/stamp.4.4/bin/linux/stamp';
our $stamp = 'stamp';
# Number of trails to run
our $nfit = 2;
# query slides every N AAs along DB sequence
our $slide = 5;
# Number of fits (residues?) to accept
our $minfit = 30;
# Min Sc value to accept
our $scancut = 2.0;
# Additional parameter string
our $parameters = 
    join(' ',
         "-s",           # scan mode: only query compared to each DB sequence
         "-secscreen F", # Do not perform initial secondary structure screen
         "-opd",         # one-per-domain: just one hit per query domain
         "-n $nfit",
         "-slide $slide",
         "-minfit $minfit",
         "-scancut $scancut", 
    );
our $cmd = "$stamp $parameters";


################################################################################
=head2 superposition_native

 Function: Calculates superposition required to put $fromdom onto $ontodom
 Example :
 Returns : L<SBG::Superposition>
 Args    : 
           fromdom: L<SBG::DomainI>
           ontodom: L<SBG::DomainI>

Does not modify/transform B<$fromdom>

This superposition considers only the original locations of the domains, based
on looking up the original PDB structure. Any transformations in the domain are
ignored. For that, see L<SBG::STAMP::superposition>.


=cut
sub superposition_native {
    my ($fromdom, $ontodom, $ops, $nocache) = @_;
    our $minfit;
    our $scancut;

    if ($fromdom == $ontodom) {
        log()->trace("Identity: $fromdom");
        return SBG::Superposition::identity($fromdom);
    }

    # Check cache
    my $superpos = $nocache ? undef : _cache_get($fromdom, $ontodom);
    if (defined $superpos) {
        # Negative cache? (i.e. superpostion previously found not possible)
        return if ref($superpos) eq 'ARRAY';
        # Cache hit
        return $superpos;
    }

    my ($fullcmd, $prefix) = _setup_input($cmd, $ontodom, $fromdom);
    my $scanfile = "${prefix}.scan";
    $fullcmd .= " $ops" if $ops;
    log()->trace("\n$fullcmd");
    system("$fullcmd > /dev/null 2>/dev/null");
    my $fh;
    unless (-s $scanfile && open($fh, $scanfile)) {
        log()->error("Error running stamp:\n$fullcmd");
        # Negative cache
        _cache_set($fromdom, $ontodom, []) unless $nocache;
        return;
    }

    
    while (my $read = <$fh>) {
        # Save only the fields, all separated by spaces
        next unless $read =~ /^\# (Sc.*?)fit_pos/;
        # Cleanup key names
        my $line = $1;
        $line =~ s/=//g;
        # Read stats into hash        
        my %stats = split ' ', $line;
        # Is this the reference domain? Skip it;
        # NB these are the same values if STAMP performed no fits
        next if $stats{nfit} == 999 && $stats{n_equiv} == 999;

        # Skip if thresh too low
        if ($stats{Sc} < $scancut || $stats{nfit} < $minfit) {
            _cache_set($fromdom, $ontodom, []) unless $nocache;
            last;
        }

        # Read in the domain being superposed onto the reference domain.
        # This contains the transformation between the (untransformed) domains
        my $io = new SBG::DomainIO::stamp(fh=>$fh);
        my $dom = $io->read;

        # Create Superposition (the reference domain, $ontodom, hasn't changed)
        $superpos = new SBG::Superposition(
            to=>$ontodom, from=>$dom, scores=>{%stats} );
        # Don't need to parse the rest once we have the transformation
        last;
    }

    unlink $scanfile unless $File::Temp::KEEP_ALL;

    if (defined $superpos) {
        _cache_set($fromdom, $ontodom, $superpos) unless $nocache;
        return $superpos;
    } else {
        _cache_set($fromdom, $ontodom, []) unless $nocache;
        return;
    }

} # superposition_native



################################################################################
=head2 superposition

 Function: 
 Example : 
 Returns : 
 Args    : 

This will produce a superposition that considers any existing transformations in
the given domains.

=cut
sub superposition {
    my ($fromdom, $ontodom, $ops) = @_;
    log()->trace("$fromdom onto $ontodom");
    my $superpos = superposition_native($fromdom, $ontodom, $ops);
    return unless defined $superpos;

    return $superpos unless ($fromdom->transformation->has_matrix || 
                             $ontodom->transformation->has_matrix);

    # Right-to-left application of transformations to get fromdom=>ontodom
    # First, inverse $fromdom back to it's native transform
    # Then, apply the transform between the native domains
    # Last, apply the transform stored in $ontodom, if any
    my $prod = 
        $ontodom->transformation x 
        $superpos->transformation x 
        $fromdom->transformation->inverse;

    $superpos->transformation($prod);
    return $superpos;

} # superposition


################################################################################
=head2 _cache_init

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub _cache_init {

    our $cache;
    unless (defined $cache) {
        my $arch = `uname -m`;
        chomp $arch;
        my $base = $ENV{CACHEDIR} || $ENV{TMPDIR} || '/tmp';
        my $cachedir = "${base}/sbgsuperposition_${arch}";
        $cache = new Cache::File(
            cache_root => $cachedir,
            lock_level => Cache::File::LOCK_NFS(),
            );
        log()->trace($cachedir);
    }
    return $cache;

} # _cache_init


################################################################################
=head2 _cache_get

 Function: 
 Example : 
 Returns : Re-retrieved object from cache
 Args    : [] implies negative caching

Cache claims to even work between concurrent processes!

=cut
sub _cache_get {
    my ($from, $to) = @_;

    my $cache = _cache_init();

    my $key = "${from}--${to}";
    my $entry = $cache->entry($key);

    if ($entry->exists) {
        my $data = $entry->thaw;
        if (ref($data) eq 'ARRAY') {
            log()->debug("Cache hit (negative) ", $key);
            return [];
        } else {
            log()->debug("Cache hit (positive) ", $key);
            return $data;
        }
    } 
    log()->debug("Cache miss ", $key);
    return;

} # _cache_get


=head2 _cache_set

 Function: 
 Example : 
 Returns : Re-retrieved object from cache
 Args    : [] implies negative caching

Cache claims to even work between concurrent processes!

=cut
sub _cache_set {
    my ($from, $to, $data) = @_;

    my $cache = _cache_init();

    # Also cache the inverse superposition
    my $key = "${from}--${to}";
    my $ikey = "${to}--${from}";

    my $entry = $cache->entry($key);
    my $ientry = $cache->entry($ikey);

    my $idata;
    # (NB [] means negative cache)
    if (ref($data) eq 'ARRAY') {
        $idata = $data;
        log()->trace("Cache write (negative) $key and $ikey");
    } else {
        $idata = $data->inverse;
        log()->trace("Cache write (positive) $key (forward)");
        log()->trace($data);
        log()->trace("Cache write (positive) $ikey (reverse)");
        log()->trace($idata);
    }

    $entry->freeze($data);
    $ientry->freeze($idata);
    # Verification;
    return $entry->exists && $ientry->exists;

} # _cache_set


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
# native=>no transformations written
# This is because we want the results on the native, unstransformed domains.
# These can be cached. 
# Any additional transformations are quick to just multiply afterward
sub _setup_input {
    my ($basecmd, $probedom, @dbdoms) = @_;

    # Write probe domain to file (native=>don't write the transformation
    my $ioprobe = new SBG::DomainIO::stamp(tempfile=>1, native=>1);
    my $probefile = $ioprobe->file;
    $ioprobe->write($probedom);
    $ioprobe->close;

    # Write database domains to single file
    my $iodb = new SBG::DomainIO::stamp(tempfile=>1, native=>1);
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


################################################################################
1;



