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

################################################################################

package SBG::CA::Assembler2;
use Moose;

use File::Spec::Functions;
use Moose::Autobox;
use Log::Any qw/$log/;

use SBG::STAMP qw/superposition/;
use SBG::GeometricHash;
use SBG::Complex;


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


has 'binsize' => (
    is => 'ro',
    isa => 'Num',
    default => 2,
    );


has 'maxsolutions' => (
    is => 'ro',
    isa => 'Int',
    default => 100,
    );


################################################################################
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
has 'pattern' => (
    is => 'ro',
    isa => 'Str',
    default => '%smodel-%05d',
    );


has 'name' => (
    is => 'ro',
    isa => 'Str',
    );


has 'dir' => (
    is => 'ro',
    isa => 'Str',
    lazy_build => 1,
    );


sub _build_dir {
    my ($self) = @_;
    return $self->name || '.';
}




################################################################################
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
    if ($state->{'net'}->has_edge($iaction->nodes)) {
        $log->debug("Edge already covered: $iaction");
        return;
    }

    # Doesn't matter which we consider to be the source/dest node
    my ($src,$dest) = $iaction->nodes;
    my $uf = $state->{'uf'};

    # Resulting complex, after (possibly) merging two disconnected complexes
    my $merged_complex;
    # Score for placing this interaction into the solutions complex forest
    my $merged_score;

    if (! $uf->has($src) && ! $uf->has($dest) ) {
        # Neither node present in solutions forest. Create dimer
        $merged_complex = SBG::Complex->new;
        $merged_score = 
            $merged_complex->add_interaction($iaction, $iaction->keys);
        
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
    
    return ($merged_complex, $merged_score);
} # test


# Closes a cycle, using a *known* interaction template
# (i.e. novel interactions not detected at this stage)
sub _cycle {
    my ($self, $state, $iaction) = @_;
    $log->debug($iaction);
    # Take either end of the interaction, since they belong to same complex
    my ($src, $dest) = $iaction->nodes;
    my $partition = $state->{'uf'}->find($src);
    my $complex = $state->{'models'}->{$partition};

    # Modify a copy
    # TODO store these thresholds (configurably) elsewhere
    my $merged_complex = $complex->clone;
    # Difference from 10 to get something in range [0:10]
    my $irmsd = $merged_complex->cycle($iaction);
    return unless defined($irmsd) && $irmsd < 15;
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

    my $src_part = $state->{'uf'}->find($src);
    my $src_complex = $state->{'models'}->{$src_part};
    my $dest_part = $state->{'uf'}->find($dest);
    my $dest_complex = $state->{'models'}->{$dest_part};

    my $merged_complex = $src_complex->clone;
    my $merged_score = $merged_complex->merge_interaction($dest_complex,$iaction);

    return ($merged_complex, $merged_score);
} # _merge


################################################################################
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
    my $add_complex = SBG::Complex->new;
    $add_complex->add_interaction($iaction, $iaction->keys);

    # Lookup complex to which we want to add the interaction
    my $ref_partition = $state->{'uf'}->find($ref);
    my $ref_complex = $state->{'models'}->{$ref_partition};
    my $merged_complex = $ref_complex->clone;
    my $merged_score = $merged_complex->merge_domain($add_complex, $ref);

    return ($merged_complex, $merged_score);

} # _add_monomer



################################################################################
=head2 solution

 Function: Callback for output/saving/printing
 Example : 
 Returns : Success: whether solution is unique and valid
 Args    : 

Bugs: assumes L<SBG::Domain::Sphere> implementation in L<SBG::Complex>
Really? Maybe it just assumes a 'centroid' method.

TODO output network toplogy of solution interaction network used to build model

=cut
sub solution {
    my ($self, $state, $partition,) = @_;
    my $complex = $state->{'models'}->{$partition};

    return -1 unless $self->classes < $self->maxsolutions;

    # Uninteresting unless at least two interfaces in solution
    return 0 unless defined($complex) && $complex->size >= $self->minsize;     

    # A new solution
    $self->solutions($self->solutions+1);

    # Get domains and their coords out of the complex model
    my $componentlabels = $complex->keys;
    my $doms = $complex->domains;

    # Use only the centroid point, less accurate, but sufficient
    my $coords = $doms->map(sub{$_->centroid});

    # Check if duplicate, based on geometric hash
    # exact() requires that the sizes match on both sides (i.e. no subsets)
    my $class = $self->gh->exact($coords, $componentlabels);

    if (defined $class) {
        $self->dups($self->dups+1);
        $log->debug('Duplicate solution. Total duplicates: ', $self->dups);
        return 0;
    } else {
        # undef => Don't name the model
        $class = $self->gh->put(undef, $coords, $componentlabels);
        return 0 unless defined $class;

        # Counter for classes created so far
#         $self->classes($class) unless $class < $self->classes;
        $self->classes($self->classes+1);
        $log->debug("Class ", $class);

        # Count number of occurences of unique complex solution *of this size*
        my $sizeclass = $complex->size;
        my $sizeclassn = $self->sizes->at($sizeclass) || 0;
        $self->sizes->put($sizeclass, $sizeclassn+1);

        $self->_write_solution($complex, $class);
    }

    $self->_status();
    # Let caller know that we accepted solution
    return 1;

} # solution


sub _write_solution {
    my ($self, $complex, $class) = @_;
    
    # Write solution to file, append an optional name and model solution
    # counter
    my $label = sprintf($self->pattern, 
                        $self->name ? $self->name . '-' : '',
                       $class, 
            );
    $complex->id($label);
    my $file .= $label . '.model';
    mkdir $self->dir;
    $file = catfile($self->dir, $file) if -d $self->dir;

    $complex->store($file);
#     $complex->write('pdb', file=>">${file}.pdb");

} # _write_solution


sub _status {
    my ($self) = @_;
    my $keys = $self->sizes->keys->sort;
    my $sizeheader = $keys->map(sub{ "%3d ${_}mers" })->join("\t");

    # Flush console and setup in-line printing, unless redirected
    if (-t STDOUT) {
        local $| = 1;
        printf 
            "\033[1K\r" . # Carriage return, i.e. w/o linefeed
            "models:\t%5d unique\t%5d dups\t %5d total\t distribution: " .
            "$sizeheader ", 
            $self->classes, $self->dups, $self->solutions,
            $keys->map(sub{ $self->sizes->at($_) })->flatten,
            ;
    }
} # _status


################################################################################
__PACKAGE__->meta->make_immutable;
no Moose;
1;


