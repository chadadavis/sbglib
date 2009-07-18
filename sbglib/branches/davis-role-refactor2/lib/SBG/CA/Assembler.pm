#!/usr/bin/env perl

=head1 NAME

SBG::Assembler - Complex assembly algorithm (callback functions)

=head1 SYNOPSIS

 use SBG::Assembler;


=head1 DESCRIPTION

The graph traversal algorithm is in L<SBG::Traversal>. This module holds call
back functions specific to building a L<SBG::Complex>.

An L<SBG::Complex> is one of many solutions to the protein complex assembly
problem for a give set of proteins.

=head1 SEE ALSO

L<SBG::Traversal> , L<SBG::Complex>

=cut

################################################################################

package SBG::CA::Assembler;
use Moose;

use Moose::Autobox;

use SBG::U::Log qw/log/;
use SBG::U::Config qw/config/;
use SBG::STAMP qw/superposition/;
use SBG::GeometricHash;


# Number of solved partial solutions
our $solution = 0;
# Number of duplicate solutions (matching an existing class)
our $dups = 0;
# Number of unique solutions, only first solution in a class is saved
our $classes = 0;
# Size distribution of unique solutions (i.e. of classes)
our %sizes;

# 3D geometric hash
our $gh = new SBG::GeometricHash(binsize=>1.5);

# TODO DES needs to be OO
my $file_pattern = '%scluster-%04d-model-%05d';

# For debugging: Individual steps within one solution
our $step = 1;



################################################################################
=head2 sub_solution

 Function: Callback for output/saving/printing
 Example : 
 Returns : Success: whether solution is unique and valid
 Args    : 

Bugs: assumes L<SBG::Domain::Sphere> implementation in L<SBG::Complex>

=cut
sub sub_solution {
    my ($complex, $graph, $nodecover, $templates, $rejects) = @_;

    # Uninteresting unless at least two interfaces in solution
    return unless $templates->length > 1;     

    # A solution is now complete. Restart at step 1 for subsequent solution
    $solution++;    
    $step = 1;

    # Get domains and their coords out of the complex model
    my $componentlabels = $complex->keys;
    my $doms = $complex->domains;
    # Use only the centroid point, less accurate, but sufficient
    my $coords = $doms->map(sub{$_->centroid});

    # Check if duplicate, based on geometric hash
    # exact() requires that the sizes match on both sides (i.e. no subsets)
    my $class = $gh->exact($coords, $componentlabels);
    if (defined $class) {
        $dups++;
        log()->debug('Duplicate solution. Total duplicates: ', $dups);
        return;
    } else {
        # undef => Don't name the model
        $class = $gh->put(undef, $coords, $componentlabels);
        # Counter for classes created so far
        $classes = $class unless $class < $classes;
        # Count number of occurences of unique complex solution *of this size*
        $sizes{scalar(@$nodecover)}++;
    }

    my $sizeheader = join(' ', map { "\#${_}-mer %3d"} sort keys %sizes);
    # Flush console and setup in-line printing, unless redirected
    if (-t STDOUT) {
        local $| = 1;
        printf 
            "\033[1K\r" . # Carriage return, i.e. w/o linefeed
            "#Aborted %5d #Solutions %5d #Dups %5d #Unique %5d Size dist.: " .
            "$sizeheader ", 
            $rejects, $solution, $dups, $classes,
            map { $sizes{$_} } sort keys %sizes,
            ;
    }
    log()->debug("\n\n====== Class: $class Solution $solution\n",
                 "@$nodecover\n", "@$templates\n", );

    # Write solution to file, append an optional name and model solution counter
    my $file = sprintf($file_pattern, 
                       $complex->id ? $complex->id . '-' : '',
                       $class, $solution);
    $complex->store($file . '.stor');

    return 1;

} # sub_solution



################################################################################
=head2 sub_test

 Function: 
 Example : 
 Returns : 
 Args    : 

Callback for attempting to add a new interaction template

Uses the hash saved in the interation object (set when templates loaded) to find
out what templates used by which components on an edge in the interaction graph

Returns true/false == success/failure to use/add interaction template

=cut

sub sub_test {
    my ($complex, $graph, $src, $dest, $iaction_id) = @_;
    log()->trace(join('|',$src,$dest,$iaction_id));

    # Interaction object, from ID, Network hashes these
    my $ix = $graph->get_interaction_by_id($iaction_id);

    # Try to add the interaction
    $complex->add_interaction($ix, $src, $dest) or return;
    # Success
    $step++;
    return 1;

} # sub_test



################################################################################
__PACKAGE__->meta->make_immutable;
no Moose;
1;


