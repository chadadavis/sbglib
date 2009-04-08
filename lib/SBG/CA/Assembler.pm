#!/usr/bin/env perl

=head1 NAME

SBG::Assembler - Complex assembly algorithm (callback functions)

=head1 SYNOPSIS

 use SBG::Assembler;


=head1 DESCRIPTION

The graph traversal is in L<SBG::Traversal>. This module holds call back
functions specific to L<SBG::Complex>.

An L<SBG::Complex> is one of many solutions to the protein complex assembly
problem for a give set of proteins.

=head1 SEE ALSO

L<SBG::Traversal> , L<SBG::Complex>

=cut

################################################################################

package SBG::CA::Assembler;
use Moose;


use Moose::Autobox;

use SBG::STAMP qw/superpose/;
use SBG::Complex;
use SBG::ComplexIO;

use SBG::Log;
use SBG::Config qw/config/;

use SBG::GeometricHash;

################################################################################
# Private

# Number of solved partial solutions
our $solution = 0;
# For debugging: Individual steps within one solution
our $step = 1;
# Number of solutions matching an existing class
our $dups = 0;
# Number of unique solutions, only first solution in a class is saved
our $classes = 0;
# Size distribution of unique solutions (i.e. of classes)
our %sizes;

my $file_pattern = '%sclass-%04d-model-%05d';

# Callback for output/saving/printing
# Bugs: assume L<SBG::Domain::CofM> implementation in L<SBG::Complex>
sub sub_solution {
    my ($complex, $graph, $nodecover, $templates, $rejects) = @_;
    our $binsize;
    $binsize = config()->val(qw/assembly binsize/) || 1.5;
    # 3D geometric hash
    our $gh;
    $gh ||= new SBG::GeometricHash(binsize=>$binsize);

    my $success = 1;
    # Uninteresting unless at least two interfaces in solution
    return unless $templates->length > 1;     

    my $labels = $complex->models->keys;
    my @doms = map { $complex->model($_) } @$labels;
    # TODO DES BUG cannot assume centre exists here
    # if these are not SBG::Domain::CofM instances
    my @points = map { $_->centre } @doms;

    $solution++;    
    $step = 1;

    # Check dup;
#     my $class = $gh->class(\@points, $labels);
    # exact() requires that the sizes match on both sides (i.e. no subsets)
    my $class = $gh->exact(\@points, $labels);
    if (defined $class) {
        $dups++;
        $logger->debug('Duplicate solution. Total duplicates: ', $dups);
        $success = 0;
    } else {
        $class = $gh->put(undef, \@points, $labels);
        $classes = $class unless $class < $classes;
        # Count number of occurences of unique complex solution of this size
        $sizes{scalar(@$nodecover)}++;
        $success = 1;
    }

    return unless $success;

    # Flush console for fancy in-place printing
    local $| = 1;
    my $sizeheader = join(' ', map { "\#${_}-mer %3d"} sort keys %sizes);
    printf 
        "\033[1K\r" . 
        "#Aborted %5d #Solutions %5d #Dups %5d #Unique %5d Size dist.: " .
        "$sizeheader ", 
        $rejects, $solution, $dups, $classes,
        map { $sizes{$_} } sort keys %sizes,
        ;



    $logger->debug("\n\n====== Class: $class Solution $solution\n",
                   "@$nodecover\n",
                   "@$templates\n",
        );

    # Append an optional name an a model solution counter
    my $file = sprintf($file_pattern, 
                       $complex->name ? $complex->name . '-' : '',
                       $class, $solution);
    $complex->store($file . '.stor');
    # Write the DOM version as well
#     my $io = new SBG::ComplexIO(file=>">$file" . '.dom');
#     $io->write($complex);


    return $success;

} # sub_solution



# TODO DOC:
# Callback for attempting to add a new interaction template

# Uses the hash saved in the interation object (set when templates loaded) to find out what templates used by which components on an edge in the interaction graph

# Returns true/false == success/failure to use/add interaction template

# Where in Assembly do we save the templates/doms that we accept?
# $complex->comp() = $dom; and $complex->iaction($key) = $ix;
sub sub_test {
    my ($complex, $graph, $src, $dest, $templ_id) = @_;
    $logger->trace(join('|',$src,$dest,$templ_id));
    my $success = 0;
    our $step;

    # Interaction object from ID
    my $ix = $graph->get_interaction_by_id($templ_id);

    $success = $complex->attach($src, $dest, $ix);

    return unless $success;

#     step2img($destdom, $complex);
#     step2dom($destdom, $complex);
    $step++;

    return $success;

} # sub_test



################################################################################
__PACKAGE__->meta->make_immutable;
1;


__END__



# TODO update
sub step2dom {
    my ($destdom, $complex) = @_;
    our $solution;
    our $step;
    $logger->trace(sprintf("step-%04d-%05d", $solution, $step));
    my @doms = ($destdom, $complex->asarray);
    my $file = sprintf("step-%04d-%05d.dom", $solution, $step);
    my $io = new SBG::DomainIO(-file=>">$file");
    $io->write($_) for @doms;
}


# TODO update
sub step2img {
    my ($destdom, $complex) = @_;
    our ($solution, $step);
    my $img = sprintf("step-%04d-%05d.ppm", $solution, $step);
    my $saved = $destdom->label;
    $destdom->label("testing");
    my $pdbfile = transform(-doms=>[$destdom, $complex->asarray]);
    $destdom->label($saved);
    # $destdom, being first in the list, will be chain A, highlight its clashes
    my $optstr = "select *A\ncolor grey\nselect (!*A and within(10.0, *A))\ncolor HotPink";
    pdb2img(-pdb=>$pdbfile, -script=>$optstr, -img=>$img);
}

