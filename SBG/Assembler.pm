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

=SEE ALSO

L<SBG::Traversal> , L<SBG::Complex>

=cut

################################################################################

package SBG::Assembler;
use Moose;

extends qw/Moose::Object Exporter/;
our @EXPORT_OK = qw(linker);

use Moose::Autobox;

use SBG::Domain;
use SBG::STAMP qw/superpose/;
use SBG::Complex;
use SBG::ComplexIO;

use SBG::Log;

################################################################################
# Private

# Number of solved partial solutions
our $solution = 1;
# For debugging: Individual steps within one solution
our $step = 1;

my $file_pattern = '%smodel-%05d';


# Callback for printing
sub sub_solution {
    my ($complex, $graph, $nodecover, $templates) = @_;
    our $solution;
    our $step;

    # Uninteresting:
    return unless $templates->length > 1;     

    # Flush console for fancy in-place printing
    local $| = 1;
    printf "\033[1K\r" . 
    "Solution# %4d: Components: %3d ",
    $solution, scalar(@$nodecover); # , join(', ', @$nodecover);

    $logger->debug("\n\n====== Solution $solution\n",
                   "@$nodecover\n",
                   "@$templates\n",
        );

    # Append an optional name an a model solution counter
    my $file = sprintf($file_pattern, 
                       $complex->name ? $complex->name . '-' : '',
                       $solution);
    $complex->store($file . '.stor');
    # Write the DOM version as well
#     my $io = new SBG::ComplexIO(file=>">$file" . '.dom');
#     $io->write($complex);

    $solution++;    
    $step = 1;

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



################################################################################
__PACKAGE__->meta->make_immutable;
1;


__END__

