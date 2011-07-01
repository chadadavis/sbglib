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

# 3D geometric hash
has 'gh' => (
    is => 'ro',
    isa => 'SBG::GeometricHash',
#     default => sub { new SBG::GeometricHash(binsize=>1.5) },
    default => sub { new SBG::GeometricHash(binsize=>2) },
    );


# File name pattern for saving assemblies
has 'pattern' => (
    is => 'ro',
    isa => 'Str',
    default => '%smodel-%05d',
    );


################################################################################
=head2 sub_solution

 Function: Callback for output/saving/printing
 Example : 
 Returns : Success: whether solution is unique and valid
 Args    : 

Bugs: assumes L<SBG::Domain::Sphere> implementation in L<SBG::Complex>
Really? Maybe it just assumes a 'centroid' method.

=cut
sub solution {
    my ($self, $complex, $graph, $nodecover, $templates, $rejects) = @_;

    $self->_status();

    # Uninteresting unless at least two interfaces in solution
    return unless defined($templates) && $templates->length > 1;     

    # A solution is now complete.
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
        log()->debug('Duplicate solution. Total duplicates: ', $self->dups);
        return;
    } else {
        # undef => Don't name the model
        $class = $self->gh->put(undef, $coords, $componentlabels);

        # Counter for classes created so far
#         $self->classes($class) unless $class < $self->classes;
        $self->classes($self->classes+1);
        log()->trace("Class ", $class);

        # Count number of occurences of unique complex solution *of this size*
        my $sizeclass = $nodecover->length;
        my $sizeclassn = $self->sizes->at($sizeclass) || 0;
        $self->sizes->put($sizeclass, $sizeclassn+1);

        # Write solution to file, append an optional name and model solution
        # counter
        my $file = sprintf($self->pattern, 
                           $complex->id ? $complex->id . '-' : '',
                           $class, 
            );
        $complex->store($file . '.stor');
    }

    return 1;

} # solution


sub _status {
    my ($self) = @_;
    my $keys = $self->sizes->keys->sort;
    my $sizeheader = $keys->map(sub{ "%3d ${_}mers" })->join(', ');

    # Flush console and setup in-line printing, unless redirected
    if (-t STDOUT) {
        local $| = 1;
        printf 
            "\033[1K\r" . # Carriage return, i.e. w/o linefeed
            "%5d unique, %5d dups, %5d total, distribution: " .
            "$sizeheader ", 
            $self->classes, $self->dups, $self->solutions,
            $keys->map(sub{ $self->sizes->at($_) })->flatten,
            ;
    }
}


################################################################################
=head2 test

 Function: 
 Example : 
 Returns : 
 Args    : 

Callback for attempting to add a new interaction template

Uses the hash saved in the interation object (set when templates loaded) to find
out what templates used by which components on an edge in the interaction graph

Returns true/false == success/failure to use/add interaction template

=cut

sub test {
    my ($self, $complex, $graph, $src, $dest, $iaction_id) = @_;
    log()->trace(join('|',$src,$dest,$iaction_id));

    # Interaction object, from ID, Network hashes these
    my $ix = $graph->get_interaction_by_id($iaction_id);

    # Try to add the interaction
    $complex->add_interaction($ix, $src, $dest) or return;
    # Success
    return 1;

} # test



################################################################################
__PACKAGE__->meta->make_immutable;
no Moose;
1;


