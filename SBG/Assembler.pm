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
use SBG::Root -base;

use SBG::Domain;
use SBG::CofM;
use SBG::STAMP;

use SBG::Complex;
use SBG::ComplexIO;

our @EXPORT_OK = qw(linker);


################################################################################
# Private

our $solution = 1;
our $step = 1;
# TODO permanent solution to output filenames
our $dir = ".";
mkdir $dir;
our $base = $dir . '/solution-%05d';

# Callback for printing
sub got_solution {
    my ($complex, $graph, $nodecover, $templates) = @_;
    # Uninteresting:
#     return unless @$templates > 1;     
#     return unless $complex->size > 3;
    return unless $complex->size > 2;
    our $solution;
    our $step;
    my $file = sprintf("${base}.dom", $solution);
    $logger->info("Solution $solution: @$nodecover\n",
                  "\t@$templates\n\t$file");

    my $io = new SBG::ComplexIO(-file=>">$file");
    return unless $io;

#     # TODO add in other junk: @$templates and @$nodecover
    foreach my $t (@$templates) {
#         my $ix = $graph->get_interaction_by_id($t);
    }
    # Write the domains with their transformations
    $io->write($complex);

    my $n = 50;
#     die "Stopping after $n solutions, on purpose " if $solution >= $n;

    $solution++;    
    $step = 1;

} # got_solution



# TODO DOC:
# Callback for attempting to add a new interaction template

# Uses the hash saved in the interation object (set when templates loaded) to find out what templates used by which components on an edge in the interaction graph

# Returns true/false == success/failure to use/add interaction template

# Where in Assembly do we save the templates/doms that we accept?
# $complex->comp() = $dom; and $complex->iaction($key) = $ix;
sub try_interaction {
    my ($complex, $graph, $src, $dest, $templ_id) = @_;
    $logger->trace(join('|',$src,$dest,$templ_id));
    my $success = 0;
    our $step;

    # Interaction object from ID
    my $ix = $graph->get_interaction_by_id($templ_id);
    # Get Domain objects used as templates in this interaction
    my $srcdom = $ix->template($src);
    my $destdom = $ix->template($dest);

    # Get reference domain of $src component
    my $srcrefdom = $complex->comp($src);
    unless (defined $srcrefdom) {
        # Base case: no previous structural constraint.
        # I.e. We're in a new frame of reference: implicitly sterically OK
        # Initialize new object, based on previous
        $complex->comp($src) = SBG::CofM::cofm($srcdom);
        # dest domain also has no explicit transformation
        $complex->comp($dest) = SBG::CofM::cofm($destdom);
        $complex->iaction($ix) = $ix;
        return $success = 1;
    }

    $destdom = linker($srcrefdom, $srcdom, $destdom);
    return $success = 0 unless $destdom;

    # Check new coords of destdom for clashes across currently assembly
    $success = ! $complex->clashes($destdom);


#     step2img($destdom, $complex);
#     step2dom($destdom, $complex);
    $step++;

    return unless $success;
    
    $complex->iaction($ix) = $ix;
    
    # Update frame-of-reference of interaction partner ($dest)
    # NB Any previous $assembly->comp($dest) gets overwritten
    # This is compatible with the backtracking of SBG::Traversal
    $complex->comp($dest) = $destdom;
    return $success;
} # try_interaction


# Transform $destdom via the linking transformation that puts src onto srcref
sub linker { 
    my ($srcrefdom, $srcdom, $destdom) = @_;
    $logger->trace("linking $srcdom onto $srcrefdom, ",
                   "in order to orient $destdom");
    # Superpose $srcdom into prev frame of reference from $src component
    # This defines the (additional) transform we need to apply to $destdom
    my $xform = superpose($srcdom, $srcrefdom);
    unless (defined($xform)) {
        $logger->error("Cannot link via: superpose($srcdom,$srcrefdom)");
        return;
    }
    # Get CofM of dest template domain (the one to be transformed)
    $destdom = SBG::CofM::cofm($destdom);

    # Then apply that transformation to the interaction partner $dest
    # Product of relative with absolute transformation
    # Any previous transformation (reference domain) has to also be included

# TODO explain order of ops here
    $destdom->transform($xform);
    $destdom->transform($srcrefdom->transformation);

    return $destdom;
}


sub step2dom {
    my ($destdom, $complex) = @_;
    our $solution;
    our $step;
    $logger->trace(sprintf("step-%04d-%05d", $solution, $step));
    my @doms = ($destdom, $complex->asarray);
    my $file = sprintf($dir . "/step-%04d-%05d.dom", $solution, $step);
    my $io = new SBG::DomainIO(-file=>">$file");
    $io->write($_) for @doms;
}


sub step2img {
    my ($destdom, $complex) = @_;
    our ($solution, $step);
    my $img = sprintf($dir . "/step-%04d-%05d.ppm", $solution, $step);
    my $saved = $destdom->label;
    $destdom->label("testing");
    my $pdbfile = transform(-doms=>[$destdom, $complex->asarray]);
    $destdom->label($saved);
    # $destdom, being first in the list, will be chain A, highlight its clashes
    my $optstr = "select *A\ncolor grey\nselect (!*A and within(10.0, *A))\ncolor HotPink";
    pdb2img(-pdb=>$pdbfile, -script=>$optstr, -img=>$img);
}



################################################################################
1;


__END__

