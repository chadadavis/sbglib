#!/usr/bin/env perl

=head1 NAME

SBG::Assembler2 - Complex assembly algorithm (callback functions)

=head1 SYNOPSIS

 use SBG::Assembler;


=head1 DESCRIPTION

The graph traversal algorithm is in L<SBG::Traversal>. This module holds call
back functions specific to building a L<SBG::Complex>.

An L<SBG::Complex> is one of many solutions to the protein complex assembly
problem for a give set of proteins.

=head1 SEE ALSO

L<SBG::Traversal> , L<SBG::Complex>

=head1 TODO

Create Complex::NR from code using GeometricHash

Iterator style: $solution = $traversal->next

This will pass from Assembler::solution to Traversal, then back to client


=cut



package SBG::CA::Assembler2;
use Moose;

use Moose::Autobox;
use Log::Any qw/$log/;
use Sort::Key qw/nsort/;

use SBG::STAMP qw/superposition/;
use SBG::GeometricHash;
use SBG::Complex;

has 'net' => (
    is => 'rw',
    isa => 'Graph',
    required => 1,
    );


=head2 

Complex to begin building from. This should already be contained in the network, but will not be rebuilt.

=cut
has 'seed' => (
    is => 'rw',
    isa => 'SBG::Complex',
    );
    
has 'target' => (
    is => 'rw',
    isa => 'SBG::Complex',
    );
    
# Number of solved partial solutions
has 'solutions' => (
    is => 'rw',
    isa => 'Int',
    default => 0,
    );


# Number of duplicate solutions (matching an existing class)
has 'dups' => (
    is => 'rw',
    isa => 'Int',
    default => 0,
    );


# Number of unique solutions, only first solution in a class is unique
has 'classes' => (
    is => 'rw',
    isa => 'Int',
    default => 0,
    );


# Size distribution of unique solutions (i.e. of classes)
has 'sizes' => (
    is => 'rw',
    isa => 'HashRef[Int]',
    default => sub { {} },
    );


# Best scoring solution per unique class
has 'best' => (
    is => 'rw',
    isa => 'HashRef[Num]',
    default => sub { {} },
    );


# Atomic bin size for deciding when solution is a duplicate set of CofMs
has 'binsize' => (
    is => 'ro',
    isa => 'Num',
    default => 2,
    );


has 'maxsolutions' => (
    is => 'ro',
    isa => 'Int',
    );



=head2 minsize

The solution callback function is only called on solutions this size or
larger. Default 0.

=cut
has 'minsize' => (
    is => 'rw',
    isa => 'Int',
    default => 3,
    );


# 3D geometric hash
has 'gh' => (
    is => 'ro',
    isa => 'SBG::GeometricHash',
    lazy_build => 1,
    );
sub _build_gh {
    my ($self) = @_;
    return SBG::GeometricHash->new(binsize=>$self->binsize);
}


# File name pattern for saving assemblies
# %s is an optional name
# %5d is the model class (one instance per class)
has 'pattern' => (
    is => 'ro',
    isa => 'Str',
    default => '%s%02d',
    );


=head2 overlap_thresh

 Function: 
 Example : 
 Returns : 
 Args    : 

Allowable fractional overlap threshold for a newly added domain. If the domain
overlaps by more than this threshold with any domain already in the complex,
then it is rejected.

=cut
has 'overlap_thresh' => (
    is => 'rw',
    isa => 'Num',
    default => 0.5,
    );


=head2 clash_thresh

Maximum allowable atomic clashes within a modelled complex. Checked once the model has been finally built. Default: 2.0 Angstrom

=cut
has 'clash_thresh' => (
    is => 'rw',
    isa => 'Num',
    default => 2.0,
    );
    

has 'irmsd_thresh' => (
    is => 'rw',
    isa => 'Num',
    default => 15,
    );
    
    
=head2 callback 

Function to call with each solution SBG::Complex

Function will be called with:
 1) model isa SBG::Complex
 2) class isa Int
 3) duplicate isa Bool
  
=cut
has 'callback' => (
    is => 'rw',
    isa => 'CodeRef',
);
  
  
=head2 test

 Function: 
 Example : 
 Returns : 
 Args    : 

Callback for attempting to add a new interaction template

A number of cases might be applicable, depending on network connectivity

Uses the hash saved in the interation object (set when templates loaded) to find
out what templates used by which components on an edge in the interaction graph

Returns true/false == success/failure to use/add interaction template

=cut
sub test {
    my ($self, $state, $iaction) = @_;
    # Skip if already covered
    if ($state->{net}->has_edge($iaction->nodes)) {
        $log->debug("Edge already covered: $iaction");
        return;
    }

    # Doesn't matter which we consider to be the source/dest node
    my ($src,$dest) = $iaction->nodes;
    my $uf = $state->{uf};

    # Resulting complex, after (possibly) merging two disconnected complexes
    my $merged_complex;
    # Score for placing this interaction into the solutions complex forest
    my $merged_score;
    
    if (! $uf->has($src) && ! $uf->has($dest) ) {
        # Neither node present in solutions forest. Create dimer
        # TODO REFACTOR
        $merged_complex = SBG::Complex->new(
            networkid => $self->net->id(),
            targetid=>$self->net->targetid(),
            target=>$self->target(),
            symmetry=>$self->net->symmetry(),
            );
        $merged_score = 
            $merged_complex->add_interaction(
                $iaction, $iaction->keys, $self->overlap_thresh);
        
    } elsif ($uf->has($src) && $uf->has($dest)) {
        # Both nodes present in existing complexes
        
        if ($uf->same($src,$dest)) {
            # Nodes in same complex tree already, attempt ring closure
            ($merged_complex, $merged_score) = 
                $self->_cycle($state, $iaction);
            
        } else {
            # Nodes in separate complexes, merge into single frame-of-ref
            ($merged_complex, $merged_score) = 
                $self->_merge($state, $iaction);

        }
    } else {
        # Only one node in a complex tree, other is new (a monomer)
        
        if ($uf->has($src)) {
            # Create dimer, then merge on $src
            ($merged_complex, $merged_score) = 
                $self->_add_monomer($state, $iaction, $src);
            
        } else {
            # Create dimer, then merge on $dest
            ($merged_complex, $merged_score) = 
                $self->_add_monomer($state, $iaction, $dest);
        }
    }

    if (defined($merged_score)) {
        $log->debug("Result: ", $merged_complex->size, '-mer');
    }
    
    return ($merged_complex, $merged_score);
    
} # test


# Closes a cycle, using a *known* interaction template
# (i.e. novel interactions not detected at this stage)
sub _cycle {
    my ($self, $state, $iaction) = @_;
    # Take either end of the interaction, since they belong to same complex
    my ($src, $dest) = $iaction->nodes;
    my $partition = $state->{uf}->find($src);
    my $complex = $state->{models}->{$partition};

    # Modify a copy
    # TODO store these thresholds (configurably) elsewhere
    my $merged_complex = $complex->clone;
    # Difference from 10 to get something in range [0:10]
    my $irmsd = $merged_complex->cycle($iaction);
  
    my $irmsd_thresh = $self->irmsd_thresh();
    my $size = $complex->size;
    if (defined($irmsd) && $irmsd <= $irmsd_thresh) {    	
        $log->debug(
           "Succeeded ($iaction) in ${size}-mer w/iRMSD ($irmsd) < threshold ($irmsd_thresh)");
    } else {    	
    	$irmsd ||= 'undef';
    	$log->debug(
    	   "Failed in ($iaction) in ${size}-mer w/iRMSD ($irmsd) > threshold ($irmsd_thresh)");
        return;
    }

    # Give this a ring bonus of +10, since it closes a ring
    # Normally a STAMP score gives no better than 10
    my $merged_score = 20 - $irmsd;
    
    return ($merged_complex, $merged_score);
} # _cycle


# Merge two complexes, into a common spacial frame of reference
sub _merge {
    my ($self, $state, $iaction) = @_;
    $log->debug($iaction);
    # Order irrelevant, as merging is symmetric
    my ($src, $dest) = $iaction->nodes;

    my $src_part = $state->{uf}->find($src);
    my $src_complex = $state->{models}->{$src_part};
    my $dest_part = $state->{uf}->find($dest);
    my $dest_complex = $state->{models}->{$dest_part};

    my $merged_complex = $src_complex->clone;
    my $merged_score = $merged_complex->merge_interaction(
        $dest_complex,$iaction, $self->overlap_thresh);

    if (defined($merged_score)) {
    	$log->debug("Succeeded: ", $merged_complex->size, '-mer');
    } else {
    	my $total = $src_complex->size + $dest_complex->size;
    	$log->debug("Failed on ${total}-mer : ", 
    	   $src_complex->size, '-mer + ', 
    	   $dest_complex->size, '-mer');
    }
    return ($merged_complex, $merged_score);
} # _merge



=head2 _add_monomer

 Function: 
 Example : 
 Returns : 
 Args    : 

Add a single component to an existing complex, using the given interaction.

One component in the interaction is homologous to a component ($ref) in the model

=cut
sub _add_monomer {
    my ($self, $state, $iaction, $ref) = @_;
    $log->debug($iaction);
    # Create complex out of a single interaction
    my $add_complex = SBG::Complex->new(
            networkid => $self->net->id(),    
            targetid=>$self->net->targetid(),
            target=>$self->target(),
            symmetry=>$self->net->symmetry(),
            );
    $add_complex->add_interaction(
        $iaction, $iaction->keys, $self->overlap_thresh);

    # Lookup complex to which we want to add the interaction
    my $ref_partition = $state->{uf}->find($ref);
    my $ref_complex = $state->{models}->{$ref_partition};
    my $merged_complex = $ref_complex->clone;
    my $merged_score = $merged_complex->merge_domain(
        $add_complex, $ref, $self->overlap_thresh);

    if (defined($merged_score)) {
        $log->debug("Succeeded: ", $merged_complex->size, '-mer');
    } else {
    	my $size = $merged_complex->size;
    	my $total = $size + 1;
    	$log->debug("Failed on ${total}-mer : ${size}-mer + 1-mer");
    }

    return ($merged_complex, $merged_score);

} # _add_monomer




=head2 solution

 Function: Callback for output/saving/printing
 Example : 
 Returns : Success: whether solution is unique and valid
 Args    : 

Bugs: assumes L<SBG::Domain::Sphere> implementation in L<SBG::Complex>
Really? Maybe it just assumes a 'centroid' method.

TODO output network toplogy of solution interaction network used to build model

Note that component labels are not used by default here, because the components may be structurally equivalent to one another, which would still result in duplicates.

=cut
sub solution {
    my ($self, $state, $partition,) = @_;
    my $complex = $state->{models}->{$partition};

    if ($self->maxsolutions && $self->classes >= $self->maxsolutions) {
    	$log->info("Max solutions reached: ", $self->maxsolutions);
    	# Stop entire traversal
    	return -1;
    } 

    # Uninteresting unless at least two interfaces in solution
    unless (defined($complex) && $complex->size >= $self->minsize) {
        $log->debug("Complex size ", $complex->size, 
            " <= minsize ", $self->minsize);
        return 0;
    }
    
    # A new solution
    $self->solutions($self->solutions+1);

    # Check duplicate
    my ($class, $coords) = $self->_check_dup($complex);

    my $score = $complex->score;
    $log->debug("score $score");
    
    # If duplicate
    if (defined $class) {
        $self->best->{$class} ||= $score; 
        # Smaller scores are better (approximates RMSD)
        if ($score && $score < $self->best->at($class)) {
            return 0 if $self->_check_clashes($complex);
            $log->info(
                "Replacing best solution for class: $class with score: $score");
            $self->_return_solution($complex, $class, 1);
            $self->best->put($class, $score);
        }
        return 0;
    } else {
        if ($self->binsize < 0) {
            # GH redundancy check disabled
        	$class = $self->solutions;
        } else {
            # Not using $componentlabels by default, 
            # as components can be homologous
            # undef implies that model is unnamed
            $class = $self->gh->put(undef, $coords);
        }
        return 0 unless defined $class;
        $log->info("New solution class: $class");

        return 0 if $self->_check_clashes($complex);
    
        $self->best->put($class, $score);
        # Counter for classes created so far
        $self->classes($self->classes+1);
        $log->debug("Class $class score $score");

        # Count number of occurences of unique complex solution *of this size*
        my $sizeclass = $complex->size;
        my $sizeclassn = $self->sizes->at($sizeclass) || 0;
        $self->sizes->put($sizeclass, $sizeclassn+1);

        $log->info(join "\t", $self->stats);

        $self->_return_solution($complex, $class);
    }

    # Let caller know that we accepted solution
    return 1;

} # solution


sub _check_dup {
    my ($self, $complex) = @_;

    # Disable GeometricHash filtering of redundant complexes when binsize < 0
    unless ($self->binsize >= 0) {
        $log->info("GeometricHash redundancy test disabled");
        return;
    }
        
    # Get domains and their coords out of the complex model
    my $componentlabels = $complex->keys;
    my $doms            = $complex->domains;
    # Use only the centroid point, less accurate, but sufficient
    my $coords = $doms->map( sub { $_->centroid } );
    # Use the 7-point crosshairs
#    my $coords = $doms->map( sub { $_->coords } );

    # Check if duplicate, based on geometric hash
    # exact() requires that the sizes match on both sides (i.e. no subsets)
    # Not using labels by default, as components can be homologous
    #     my $class = $self->gh->exact($coords, $componentlabels);
    $log->debug( "binsize ", $self->binsize );
    my $class = $self->gh->exact($coords);
    if (defined $class) {
        $self->dups($self->dups+1);
        $log->debug("Duplicate of class $class. Duplicates: ", $self->dups);
    }
    return wantarray ? ($class, $coords) : $class;
}


sub _check_clashes {
    my ($self, $complex) = @_;

    my $clashes = $complex->vmdclashes();
    unless ( $clashes <= $self->clash_thresh ) {
        $log->info( "Clashes ($clashes) exceeds threshold ",
            $self->clash_thresh );
        return 1;
    }
    return 0;
}


# Write solution to file, append an optional name and model solution
# counter
sub _return_solution {
    my ($self, $complex, $class, $duplicate) = @_;
            
    my $label = sprintf($self->pattern, '', $class);
    $complex->modelid($label);
    $complex->class($class);
        
    # Superpose to target, if given (do this after setting the model id)
    _benchmark($complex, $self->target);

    my $callback = $self->callback;
    return unless defined $callback;
    $callback->($complex, $class, $duplicate, $self->stats, $self->net);
        
} # _return_solution


# TODO belongs in SBG::Complex, called from Complex::_build_scores

sub _benchmark {
    my ($model, $target) = @_;
    return unless defined $target;
    $log->debug("model $model");
    $log->debug("target ", $model->targetid);
    
    # Target complex to be benchmarked against
    $model->target($target);
    
    my ($benchmatrix, $benchrmsd, $benchmapping, $benchnatoms) = 
        $model->rmsd_class($target);
    $log->debug($benchrmsd);
    $log->debug($benchmatrix);
        if (defined $benchmatrix) {
            # Do the actual superposition onto the target
            $model->transform($benchmatrix);
            $model->scores->put('rmsd', $benchrmsd);
            $model->scores->put('rmsdnatoms', $benchnatoms);
            $model->correspondance($benchmapping);
        } else {
            $benchrmsd = 'NaN';
        }
    
    return wantarray ? ($benchrmsd, $benchmatrix, $benchnatoms) : $benchrmsd;
}


sub stats {
    my ($self) = @_;
    # starting with 1mers, 2mers, etc
    my @sizes = nsort $self->sizes->keys->flatten;
    my @stats = 
        ('unique' => $self->classes,
         'total'  => $self->solutions,
         'dups'   => $self->dups,
        );
    push(@stats, ("${_}mers", $self->sizes->at($_))) for @sizes;

    return \@stats;
}



__PACKAGE__->meta->make_immutable;
no Moose;
1;





