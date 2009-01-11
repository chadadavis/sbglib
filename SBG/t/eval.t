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
use SBG::CofM;
use SBG::DomainIO;

use PDL;
use PDL::Matrix;

our $truth = new SBG::ComplexIO(-file=>"2nn6abcdef.dom")->read;
# $truth = SBG::CofM::cofm($truth);

# our $compare = new SBG::ComplexIO(-file=>"sol9post.dom")->read;
# take2($compare);
# exit;

my $template_network = new SBG::NetworkIO(-file=>'ex_small.csv')->read;
my $traversal = new SBG::Traversal(-graph=>$template_network, 
                                   -test=>\&SBG::Assembler::try_interaction, 
#                                    -partial=>\&evalsolution,
                                   -partial=>\&take2,
                                   # Only maximally complete complex solutions
                                   -minsize=>scalar($template_network->vertices),
    );
# Each solution will be returned as an SBG::Complex
$traversal->traverse(new SBG::Complex);




################################################################################

sub take2 {
    my ($complex, $graph, $nodecover, $templates) = @_;
    our $truth;
    our $counter;
    $counter++;
    return if $counter > 1;

    new SBG::ComplexIO(-file=>">sol${counter}pre.dom")->write($complex);
    print "\nSolution: $counter\n";
    my ($rmsd, $trans) = min_rmsd($complex, $truth);
    print "\tRMSD: $rmsd\n";

    # Combined result, true complex first
    my $io = new SBG::ComplexIO(-file=>">joint${counter}.dom");
    $truth->transform($trans);
    $io->write($truth);
    $io->write($complex);
    # Don't forget to switch back
    $truth->transform($trans->inverse);

    # Double check
    print "Rereading solution $counter pre ...\n";
    $complex = new SBG::ComplexIO(-file=>"sol${counter}pre.dom")->read;
    ($rmsd, $trans) = min_rmsd($complex, $truth);
    print "RMSD reread $counter pre: $rmsd\n";

}

# NB; this will only work if the $complex2 hasn't yet been transformed
sub min_rmsd {
    my ($model, $truth) = @_;
    my $minrmsd = "Infinity";
    my $mintrans;
    my $minname;
    my %names;
    $names{$_} = 1 for $model->names;
    $names{$_} = 1 for $truth->names;
    foreach my $name (keys %names) {
        # Only consider common components
        my $mdom = $model->comp($name);
        my $tdom = $truth->comp($name);
        $logger->info("Missing $name from model") unless $mdom;
        $logger->info("Additional $name in model") unless $tdom;
        next unless $mdom && $tdom;
        print 
            "Joining on: $name\n", 
            "\t", $mdom->_cofm2string, " vs ", $tdom->_cofm2string, "\n";
        my $trans = superpose($tdom, $mdom);
        # Product of these transformations:
        $trans = $mdom->transformation * $trans;
        print  "\tpre complex RMSD: ", $model - $truth, "\n";

        $truth->transform($trans);

        my $rmsd = $model - $truth;
        print "\tpost complex RMSD: $rmsd\n";
        print "\tcomponent $name RMSD: ", $mdom - $tdom, "\n";


        # Don't forget to reset back to original frame of reference
        $truth->transform($trans->inverse);

        if ($rmsd < $minrmsd) {
            $minrmsd = $rmsd;
            $mintrans = $trans;
            $minname = $name;
            print "\t(new min)";
        }
        print "\n";
        print "\t", new SBG::DomainIO()->write($mdom), "\n";
    }
    print "Min RMSD: $minrmsd (via $minname)\n";
    return $minrmsd unless wantarray;
    return $minrmsd, $mintrans;
}


sub evalsolution {
    my ($complex, $graph, $nodecover, $templates) = @_;
    our $truth;
    our $counter;
    $counter++;
    return if $counter > 1;

    my $transsum = mpdl zeroes(4,4);

    print "Solution: $counter\n";

    new SBG::ComplexIO(-file=>">sol${counter}pre.dom")->write($complex);
    my $components = 0;
    my $trans;

    foreach my $name ($truth->names) {
        # NB this dom has no cofm
#         my $truedom = $truth->comp($name);
        my $truedom = SBG::CofM::cofm($truth->comp($name));
        my $modeldom = $complex->comp($name);
        unless ($modeldom) {
            print STDERR "$name is not in solution $counter\n";
            next;
        }
        $components++;
        print "\t$truedom vs $modeldom\n";
        print "orig trans:\n", $modeldom->transformation, "\n";
        my $rmsd = $truedom - $modeldom;
        print "\tpre-rmsd:$rmsd : " . 
            $truedom->_cofm2string . "," . $modeldom->_cofm2string . "\n";
        $trans = superpose($modeldom,$truedom);
#         $trans ||= superpose($modeldom,$truedom);
        
        print "\ttransform:\n$trans\n";
        $transsum .= $transsum+$trans->matrix;

#         $modeldom->transform($trans);

    }
#     print "transsum:\n\t$transsum\n";
    my $mean = $transsum/$components;
    print "\n\tmean trans:$mean";
    my $mtrans = new SBG::Transform(-matrix=>$mean);

    my $rmsdsum;
    foreach my $name ($truth->names) {
        # NB this dom has no cofm
#         my $truedom = $truth->comp($name);
        my $truedom = SBG::CofM::cofm($truth->comp($name));

        my $modeldom = $complex->comp($name);
        unless ($modeldom) {
            print STDERR "$name is not in solution $counter\n";
            next;
        }

        $modeldom->transform($mtrans);

        my $postrmsd = $truedom - $modeldom;
        print "\tpost-rmsd:$postrmsd : " . 
            $truedom->_cofm2string . "," . $modeldom->_cofm2string . "\n";
        print $modeldom->transformation, "\n";

        $rmsdsum += $postrmsd;
    }    
    my $meanrmsd = $rmsdsum/$components;
    print "Solution $counter, RMSD mean: $meanrmsd\n";
    new SBG::ComplexIO(-file=>">sol${counter}post.dom")->write($complex);
    my $io = new SBG::ComplexIO(-file=>">joint${counter}.dom");
    $io->write($truth);
    $io->write($complex);
}
