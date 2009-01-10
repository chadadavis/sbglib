#!/usr/bin/env perl

use Test::More 'no_plan';

use strict;

use SBG::NetworkIO;
use SBG::Assembler;
use SBG::Traversal;
use SBG::ComplexIO;
use SBG::Complex;
use SBG::STAMP;
use SBG::Transform;

use PDL;
use PDL::Matrix;

my $truth = new SBG::ComplexIO(-file=>"2nn6abcdef.dom")->read;
my $template_network = new SBG::NetworkIO(-file=>'ex_small.csv')->read;
my $traversal = new SBG::Traversal(-graph=>$template_network, 
                                   -test=>\&SBG::Assembler::try_interaction, 
                                   -partial=>\&evalsolution,
                                   # Only maximally complete complex solutions
                                   -minsize=>scalar($template_network->vertices),
    );
# Each solution will be returned as an SBG::Complex
$traversal->traverse(new SBG::Complex);

sub evalsolution {
    my ($complex, $graph, $nodecover, $templates) = @_;

    our $counter;
    $counter++;
    return if $counter > 1;
    my $transsum = mpdl zeroes(4,4);

    print "Solution: $counter\n";

    new SBG::ComplexIO(-file=>">sol${counter}pre.dom")->write($complex);
    my $components = 0;
#     my $raw = mpdl zeroes(4,4);
    my $raw = idtransform;
    $raw->slice('0,0') .= -0.31566;

    $raw->slice('0,3') .= 0.23;
    $raw->slice('1,3') .= -0.44;
    $raw->slice('2,3') .= .1234;
    $raw->slice('3,3') .= 1;
    my $trans = new SBG::Transform(-matrix=>$raw);

    foreach my $name ($truth->names) {
        my $truedom = $truth->comp($name);
        my $modeldom = $complex->comp($name);
        unless ($modeldom) {
            print STDERR "$name is not in solution $counter\n";
            next;
        }
        $components++;
        print "\t$truedom vs $modeldom\n";
        print "orig:\n", $modeldom->transformation, "\n";
        my $rmsd = $truedom - $modeldom;
        print "\tpre-rmsd:$rmsd\n";
#         my $trans = superpose($modeldom,$truedom);
        $trans ||= superpose($modeldom,$truedom);
        
#         $modeldom->transform($trans);
        print "\ttransform:\n$trans\n";
        $transsum .= $transsum+$trans->matrix;

        $modeldom->transform($trans);
#         $modeldom->transformation($trans);
        my $postrmsd = $truedom - $modeldom;
        print "\tpost-rmsd:$postrmsd\n";
        print $modeldom->transformation, "\n";
    }
#     print "transsum:\n\t$transsum\n";
    my $mean = $transsum/$components;
    print "\n\tmean:$mean";
    my $mtrans = new SBG::Transform(-matrix=>$mean);

    my $rmsdsum;
    foreach my $name ($truth->names) {
        my $truedom = $truth->comp($name);
        my $modeldom = $complex->comp($name);
        unless ($modeldom) {
            print STDERR "$name is not in solution $counter\n";
            next;
        }
#         $modeldom->transform($mtrans);
#         my $rmsd = $truedom - $modeldom;
#         print "\tpost-rmsd:$rmsd\n";
#         $rmsdsum += $rmsd;
    }    
#     my $meanrmsd = $rmsdsum/$components;
#     print "Solution $counter, RMSD mean: $meanrmsd\n";
    new SBG::ComplexIO(-file=>">sol${counter}post.dom")->write($complex);
}
