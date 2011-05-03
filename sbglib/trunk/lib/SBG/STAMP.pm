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

STAMP is available under the open-source GPL license 

=cut



package SBG::STAMP;
use strict;
use warnings;
use base qw/Exporter/;

our @EXPORT_OK = qw/superposition/;


use Moose::Autobox;
use File::Temp;
use PDL::Lite;
use PDL::Core qw/pdl/;
use Log::Any qw/$log/;

use SBG::DomainIO::stamp;
use SBG::Superposition;
use SBG::Domain::Sphere;
use SBG::Run::cofm qw/cofm/;


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
    my ($fromdom, $ontodom, $ops) = @_;
    our $minfit;
    our $scancut;

    my $fromfile = $fromdom->file;
    my $ontofile = $ontodom->file;
    if ($fromfile eq $ontofile && 
        $fromdom->descriptor eq $ontodom->descriptor        
        ) {
        $log->debug("Identity: $fromdom");
        return SBG::Superposition->identity($fromdom);
    }

    my $cmd = "$stamp $parameters";

    my ($fullcmd, $prefix) = _setup_input($cmd, $ontodom, $fromdom);
    my $scanfile = "${prefix}.scan";
    $log->debug("\n$fullcmd");
    system("$fullcmd > /dev/null 2>/dev/null");
    my $fh;
    unless (-s $scanfile && open($fh, $scanfile)) {
        $log->error("$fromdom => $ontodom : Can't read: $scanfile:\n$fullcmd");
        return;
    }

    my $superpos;
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
            last;
        }

        # Read in the domain being superposed onto the reference domain.
        # This contains the transformation between the (untransformed) domains
        my $io = new SBG::DomainIO::stamp(fh=>$fh);
        my $dom = $io->read;

        # Create Superposition (the reference domain, $ontodom, hasn't changed)
        $superpos = SBG::Superposition->new(
            from=>$fromdom->clone,
            to=>$ontodom->clone,
            transformation=>$dom->transformation,
            scores=>{%stats},
            );
        # Don't need to parse the rest once we have the transformation
        last;
    }

    unlink $scanfile unless $File::Temp::KEEP_ALL;

    return $superpos;

} # superposition_native





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
    $log->debug($fromdom->uniqueid, '=>', $ontodom->uniqueid);
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



1;



