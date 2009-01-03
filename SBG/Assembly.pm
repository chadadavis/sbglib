#!/usr/bin/env perl

=head1 NAME

SBG::Assembly - Represents one solution to the problem of assembling a complex

=head1 SYNOPSIS

 use SBG::Assembly;


=head1 DESCRIPTION



=SEE ALSO

L<SBG::AssemblyIO> , L<SBG::Domain>

=cut

################################################################################

package SBG::Assembly;
use SBG::Root -Base, -XXX;

# This object is clonable
use base qw(Clone);

# Allowed (linear) overlap between the spheres, that represent the proteins
# Centre-of-mass + Radius-of-gyration
field 'clash';


use overload (
    '""' => '_asstring',
    'eq' => '_eq',
    );


################################################################################
=head2 new

 Title   : new
 Usage   : 
 Function: 
 Returns : 
 Args    : -clash Tolerance (angstrom) for overlaping radii of gyration

=cut
sub new () {
    my ($class, %o) = @_;
    my $self = { %o };
    bless $self, $class;
    $self->_undash;

    $self->{clash} = $config->val('assembly', 'clash') || '30';

    return $self;
} # new


################################################################################
=head2 clone

 Title   : clone
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :

A shallow copy, copies hashes and their pointers.  Doesn't copy referenced
Domain/Transform objects.  This is necessary, as backtracking graph traversal
creates many Assemblys.

Depth 2 means: copy assembly (1) and the hashes/objects in Assembly (2).  Does
not copy what is referenced in/from the hashes/objects (3).

I.e. Assembly can efficiently contain references to other objects without
incurring a cloning copy penalty.

=cut
sub clone {
    $self->Clone::clone(shift || 2);
} # clone


################################################################################
=head2 size

 Title   : size
 Usage   : $assembly->size;
 Function: Number of components in the current Assembly
 Example : $assembly->size;
 Returns : ents in the current Assembly
 Args    : NA


=cut
sub size {
    return scalar(keys %{$self->{comp}});
}


################################################################################
=head2 comp

 Title   : comp
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :

The component L<SBG::Domain> objects collected in this Assembly.  NB These also
contain centres-of-mass as well as Transform's

The return value of this method can be assigned to, e.g.:

 $assem->comp('mylabel') = $domainobject;

NB Spiffy doesn't magically create $self here, probably due to the attribute
=cut
sub comp : lvalue {
    my ($self,$key) = @_;
    $self->{comp} ||= {};
    # Do not use 'return' with 'lvalue'
    $self->{comp}{$key};
} # comp


sub iaction : lvalue {
    my ($self,$key) = @_;
    $self->{iaction} ||= {};
    # Do not use 'return' with 'lvalue'
    $self->{iaction}{$key};
}


################################################################################
=head2 clashes

 Title   : clashes
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :

Determine whether a given L<SBG::Domain> (containing a centre-of-mass with a
radius of gyration), would create a clash/overlap in space with any of the
L<SBG::Domain>s in this Assembly.

=cut
sub clashes {
    my $newdom = shift;

    # Get all of the objects in this assembly. 
    # If any of them clashes with the to-be-added objects, then disallow
    foreach my $key (keys %{$self->{comp}}) {
        # Measure the overlap between $newdom and each component
        my $overlap = $newdom->overlap($self->comp($key));
        print STDERR 
            "\toverlap: ", $newdom->id, "/", $self->comp($key)->id, 
            " $overlap\n";
        if ($overlap > $self->clash) {
            print STDERR "\t$newdom clashes\n";
            return 1;
        }
    }
    print STDERR "\t$newdom fits\n";
    return 0;
} # clashes


sub _asstring {
    join ",", sort keys %{$self->{iaction}};
}


sub _eq {
    my $other = shift;
    return "$self" eq "$other";
}








sub lastedge {
    my ($self, $traversal) = @_;
    my $io = new AssemblIO();
    $io->write($self) if $self->size() > 2;
}


sub lastnode {
    my ($self, $traversal) = @_;
    my $io = new AssemblIO();
    $io->write($self) if $self->size() > 2;
}




# Callback for attempting to add a new interaction template
# Gets an assembly object as a status object
sub try_edge {
#     my ($u, $v, $traversal, $ix_index) = @_;
    my ($u, $v, $traversal, $assembly) = @_;

#     $ix_index ||= 0;

    print STDERR "\ttry_edge $u $v:\n";
    my $g = $traversal->{graph};

    # IDs of Interaction's (templates) in this Edge
    my @ix_ids = $g->get_edge_attribute_names($u, $v);
    @ix_ids = sort @ix_ids;

    # Extract current state of this edge, if any
    my $edge_id = "$u--$v";
    # Which of the interaction templates, for this edge, to try (next)
    my $ix_index = $traversal->get_state($edge_id . "ix_index") || 0;

    # If no templates (left) to try, cannot use this edge
    unless ($ix_index < @ix_ids) {
        print STDERR "\tNo more templates\n";
        # Now reset, for any subsequent, independent attempts on this edge
        $traversal->set_state($edge_id . "ix_index", 0);
        return undef;
    }

    # Try next interaction template
    my $ix_id = $ix_ids[$ix_index];
    print STDERR "\ttemplate ", 1+$ix_index, "/" . @ix_ids . "\n";
    my $ix = $g->get_interaction_by_id($ix_id);
#     print STDERR "$ix ";

    # Structural compatibility test (backtrack on failure)
    my $success = try_interaction3($assembly, $ix, $u, $v);


#     $traversal->set_state($edge_id . "success", $success);

    # Next interaction iface to try on this edge
    $ix_index++;
    $traversal->set_state($edge_id . "ix_index", $ix_index);

    print STDERR "\n";

    if ($success) {

        # Add this template to progressive solution
        $assembly->add($ix_id);
        return 1;

    } else {
        # This means failure, 
        # This is not the same as exhausting the templates (that's undef)
        return -1;
        # I.e. do not recurse here
    }

} # try_edge





# TODO DOC:
# Uses the hash saved in the interation object (set when templates loaded) to find out what templates used by which components on and edge in the interaction graph
sub try_interaction3 {
    my ($assembly, $iaction, $src, $dest) = @_;
    my $success = 0;

    # Lookup $src in $iaction to identify its monomeric template domain
    my $srcdom = $iaction->{template}{$src};
    my $destdom = $iaction->{template}{$dest};
    print STDERR "\t$src($srcdom)->$dest($destdom)\n";

    # Get reference domain of $src 
    my $srccofm = $assembly->cofm($src);

    unless (defined $srccofm) {
        # base case: no previous structural constraint, implicitly sterically OK
        $srccofm = new SBG::CofM($src, $srcdom);
        # Save CofM object for src component in assembly, indexed by $src
        $assembly->cofm($src, $srccofm);
        my $destcofm =  new SBG::CofM($dest, $destdom);
        $assembly->cofm($dest, $destcofm);
        return $success = 1;
    }

    # Find the frame of reference for the source
    # STAMP dom identifier (PDBID/CHAINID), TODO should be a descriptor
    my $refdom = $srccofm->id;

    # Superpose this template dom of the src component onto the reference dom
    # TODO abstract this into a DB cache as well
    my $nexttrans = stampfile($srcdom, $refdom);
    if (! defined $nexttrans) { 
        return $success = 0; 
    }

    # Then apply that transformation to the interaction partner $dest
    # Get CofM of dest template domain (the one to be transformed)
    # NB Any previous $assembly->cofm($dest) gets overwritten
    my $destcofm =  new SBG::CofM($dest, $destdom);

    # Product of relative with absolute transformation
    # TODO DOC order of mat. mult.
    $destcofm->apply($srccofm->cumulative * $nexttrans);

    # Check new coords of dest for clashes across currently assembly
    $success = ! $assembly->clashes($destcofm);
    if ($success) {
        # Update frame-of-reference of interaction partner
        $assembly->cofm($dest, $destcofm);
    }

    print STDERR "\ttry_interaction ", $success ? "succeeded" : "failed", "\n";
    return $success;

} # try_interaction3




################################################################################
1;


__END__

