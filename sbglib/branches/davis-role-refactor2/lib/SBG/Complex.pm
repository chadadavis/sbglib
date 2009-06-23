#!/usr/bin/env perl

=head1 NAME

SBG::Complex - Represents one solution to the problem of assembling a complex

=head1 SYNOPSIS

 use SBG::Complex;


=head1 DESCRIPTION

A state-holder for L<SBG::Traversal>.  L<SBG::Assembler> uses L<SBG::Complex> to
hold state-information while L<SBG::Traversal> traverses an L<SBG::Network>.

In short, an L<SBG::Complex> is one of many
solutions to the protein complex assembly problem for a give set of proteins.

=head1 SEE ALSO

L<SBG::ComplexIO> , L<SBG::Assembler> , L<SBG::Traversal>

=cut

################################################################################

package SBG::Complex;
use Moose;

extends qw/Moose::Object Clone/;
with qw/
SBG::Role::Storable
SBG::Role::Clonable
/;


use Moose::Autobox;
use autobox ARRAY => 'SBG::U::List';
use File::Temp qw/tempfile/;
use Module::Load;

use SBG::HashFields;
use SBG::U::List qw/min union sum intersection/;
use SBG::U::Config qw/config/;
use SBG::U::Log;
use SBG::STAMP qw/superpose stamp/;
# TODO stamp() only used by complexrmsd() . Remove it.

use SBG::DomainI;
use SBG::Domain;
use SBG::DomainIO;
# Default Domain subtype
use SBG::Domain::CofM;

use overload (
    '""' => 'stringify',
    fallback => 1,
    );


################################################################################
# Fields and accessors


=head2 name

Just for keeping track of which complex models correspond to which networks

=cut
has 'name' => (
    is => 'ro',
    isa => 'Str',
    default => '',
    );


=head2 type

The sub-type to use for any dynamically created objects. Should be
L<SBG::Domain> or a sub-class of that. Default "L<SBG::Domain>" .

=cut
has 'type' => (
    is => 'rw',
    isa => 'ClassName',
    required => 1,
    default => 'SBG::Domain',
    );

# ClassName does not validate if the class isn't already loaded. Preload it here.
before 'type' => sub {
    my ($self, $classname) = @_;
    return unless $classname;
    Module::Load::load($classname);
};


################################################################################
n=head2 interaction

L<SBG::Interaction> objects used to create this complex. Indexed by the
B<primary_id> of the interaction.

=cut
hashfield 'interaction', 'interactions';


################################################################################
=head2 template

 Function: 
 Example : $cmplx->template('RRP43',new SBG::Template(seq=>$seq,domain=>$dom);
 Returns : A ref to the L<SBG::Domain> for the component name given
 Args    :

Indexed by accession_number of protein modelled by this template.

=cut
# hashfield 'template', 'templates';


################################################################################
=head2 model

 Function: Maps accession number of protein components to L<SBG::Domain> model.
 Example : $cmplx->domain('RRP43',
               new SBG::Domain::CofM(pdbid=>'2xyz',descriptor='CHAIN A'));
 Returns : The one L<SBG::Domain> modelling the protein, if any
 Args    : accession_number

Indexed by accession_number of protein modelled by this L<SBG::Domain>

=cut
hashfield 'model', 'models';



################################################################################
=head2 stringify

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub stringify {
    (shift)->interactions->keys->sort->join(',');
}


################################################################################
=head2 size

 Function: Number of modelled components in the current complex assembly
 Example : $assembly->size;
 Returns : Number of components in the current complex assembly
 Args    : NA

=cut
sub size {
    my ($self) = @_;
    return $self->models->keys->length;
}


################################################################################
=head2 names

 Function:
 Example :
 Returns : Names of the component proteins being modelled in this complex
 Args    :

List is sorted

=cut
sub names {
    my $a = (shift)->models->keys->sort;
    return wantarray ? @$a : $a;
}


################################################################################
=head2 attach

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub attach {
    my ($self, $src, $dest, $ix) = @_;
    my $success;
    # These two domains may be abstract (i.e. no spacial representation)
    my $srcdom = $ix->template($src)->domain;
    my $destdom = $ix->template($dest)->domain;
    # Get reference domain of $src component (a concrete domain, w/ coordinates)
    my $refdom = $self->model($src);

    unless (defined $refdom) {
        # Base case: no previous structural constraint.
        # I.e. We're in a new frame of reference: implicitly sterically OK
        # Initialize new object, based on previous (copy construction)

        $self->model($src, $srcdom->clone());
        $self->model($dest, $destdom->clone());
        $self->interaction($ix, $ix);
        return $success = 1;
    }

    $destdom = $self->linker($refdom, $srcdom, $destdom);
    return $success = 0 unless $destdom;

    # Check new coords of destdom for clashes, across doms in currently assembly
    my $meanoverlapfrac = $self->trydomain($destdom);

    # TODO DES this is poor logic, side effect 1 means bogus, but less than 1
    $success = $meanoverlapfrac < 1;
    return unless $success;

    # Domain does not clash after being oriented, can be saved in complex now
    # Update frame-of-reference of interaction partner ($dest)
    # NB Any previous $self->domain($dest) gets overwritten
    # This is compatible with the backtracking of SBG::Traversal
    $destdom->clash($meanoverlapfrac);
    $self->model($dest, $destdom);
    $self->interaction($ix, $ix);
    return $success;

} # attach


# Transform $destdom via the linking transformation that puts src onto srcref
# TODO explain order of ops here
sub linker { 
    my ($self, $srcrefdom, $srcdom, $destdom) = @_;
    $logger->trace("linking $srcdom onto $srcrefdom, ",
                   "in order to orient $destdom");
    # Superpose $srcdom into prev frame of reference from $src component
    # This defines the (additional) transform we need to apply to $destdom
    my $xform = superpose($srcdom, $srcrefdom);
    unless (defined($xform)) {
        $logger->info("Cannot link via: superpose($srcdom,$srcrefdom)");
        return;
    } else {
        $logger->trace("Succeeded.",
                       " Sc:", $xform->{'Sc'}, 
                       " RMS:", $xform->{'RMS'},
            );
    }

    # Concrete (w/ coordinates) instance of this domain, of class $self->type()
    my $type = $self->type;
    $destdom = $type->new(%$destdom);

    # Then apply that transformation to the interaction partner $dest
    # Product of relative with absolute transformation
    # Any previous transformation (reference domain) has to also be included

# TODO explain order of ops here
    $destdom->transform($xform);
    $destdom->transform($srcrefdom->transformation);

    # Note the linker transformation used, for scoring later
    # Track these as superposition objects
#     $destdom->linker($xform);

    return $destdom;
} # linker


################################################################################
=head2 subnet

 Function: Derive a new L<SBG::Network> from this complex
 Example : 
 Returns : L<SBG::Network>
 Args    : NA

# TODO

=cut
sub subnet {
    my ($self) = @_;

    # NB subnet cannot simply call subgraph, as we only want specific
    # interactions for given nodes, not all interaction between two nodes, as
    # subgraph() would tend to do it.  No way to remove interactions, either,
    # i.e. we'll have to build subnet manually

    # Go through %{ $self->interactions }
    # foreach my $i (@{$self->interactions->values}) {
    #   @nodes = $i->nodes;
    #   $net->add($_) for @nodes;
    #   $net->add_interaction(
    #              -nodes=>[@nodes],-interaction=>$i);

} # subnet


################################################################################
=head2 trydomain

 Function:
 Example :
 Returns : 
 Args    :

Determine whether a given L<SBG::Domain> would create a clash/overlap in space
with any of the L<SBG::Domain>s in this complex.

=cut
sub trydomain {
    my ($self, $newdom) = @_;
    # Get all of the objects in this assembly. 
    # If any of them clashes with the to-be-added objects, then disallow
    # TODO config this config.ini
    my $thresh = .5;
    my $overlaps = [];
    foreach my $key ($self->names) {
        # Measure the overlap between $newdom and each component
        my $existingdom = $self->model($key);
        $logger->trace("$newdom vs $existingdom");
        my $overlapfrac = $newdom->evaluate($existingdom);
        # Nonetheless, if one clashes severely, bail out
        return 1 if $overlapfrac > $thresh;
        # Don't worry about domains that aren't overlapping at all (ie < 0)
        $overlaps->push($overlapfrac) if $overlapfrac > 0;
    }
    my $mean = $overlaps->mean || 0;
    $logger->info("$newdom fits w/ mean overlap fraction: ", $mean);
    return $mean;
} 


# Mean clash score within a complex (between components)
sub clashes {
    my ($self) = @_;
    my $doms = $self->models->values;
    my $clashes = [ map { $_->clash } @$doms ];
    return $clashes->mean;
}


################################################################################
=head2 transform

 Title   : transform
 Usage   :
 Function: Transforms each component L<SBG::Domain> by a given L<SBG::Transform>
 Example :
 Returns : 
 Args    :


=cut
sub transform {
   my ($self,$trans) = @_;
   foreach my $name ($self->names) {
       $self->model($name)->transform($trans);
   }
} # transform


# TODO DOC
# TODO DES should only be available in specialized subclass
sub crosshairs {
    my ($self) = @_;
    foreach my $domname ($self->names) {
        my $dom = $self->model($domname);
        $dom->crosshairs();
    }
    return $self;
}


################################################################################
=head2 min_rmsd

 Function:
 Example :
 Returns : minrmsd, mintrans, minname
 Args    :

NB; this will only work if the $truth hasn't yet been transformed.

Because it relies on being able to put the complex $truth into the frame of
reference of the template domains used to build the $model complex. 

=cut
sub min_rmsd {
    my ($model, $truth) = @_;
    my $minrmsd;
    my $mintrans;
    my $minname = '';
    # Only consider common components
    my @cnames = intersection([$model->names], [$truth->names]);

    # Define 7pt cross-hair centre of mass for model complex
    # TODO DES this assumes an implementation, need to subclass Complex!
    $model->crosshairs();

    # For each joining domain
    foreach my $name (@cnames) {
        my $mdom = $model->model($name);
        my $tdom = $truth->model($name);
        $logger->trace("Attempting join via: $name");
        my $trans = superpose($tdom, $mdom);
        unless ($trans) {
            $logger->debug("Cannot join via: $name");
            next;
        }
        # Before transforming, setup the crosshairs on benchmark complex
        $truth->crosshairs();

        # Product of these transformations: (applying $trans, then from $mdom)
        $trans = $mdom->transformation x $trans;
        $truth->transform($trans);
        $logger->debug("Resulting RMSD on $name: ", $mdom->rmsd($tdom));
        my $rmsd = $model->rmsd($truth);
        $logger->debug("Resulting RMSD on complex: $rmsd");
        # Don't forget to reset back to original frame of reference
        $truth->transform($trans->inverse);

        if (!defined($minrmsd) || $rmsd < $minrmsd) {
            $minrmsd = $rmsd;
            $mintrans = $trans;
            $minname = $name;
        }
    }
    $minrmsd ||= 'nan';
    $logger->debug("Min RMSD: $minrmsd ($minname)");
    return ! wantarray ? $minrmsd : ($minrmsd, $mintrans, $minname);

} # min_rmsd


# Superpose a complex onto another, using min_rmsd

# Uses min_rmsd to find a suitable superposition into a common frame of ref.
# Chains A,C,E, etc are the model ($self)
# Chains B,D,F, etc are the comparison/benchmark ($other)
sub csuperpose {
    my ($self, $other, $andwrite, $showall) = @_;
    # The transformation required to put $other into fram-of-reference of $self
    my ($minrmsd, $mintrans, $minname) = $self->min_rmsd($other);
    $other->transform($mintrans);

    if ($andwrite) {
        my @doms;
        if ($showall) {
            @doms = ( @{ $self->models->values }, @{ $other->models->values });
        } else {
            my @cnames = intersection([$self->names], [$other->names]);
            @doms = map { $self->model($_), $other->model($_) } @cnames;
        }
        my $file = SBG::STAMP::gtransform(doms=>\@doms);
        return $file;
    }
}


# How well do the domains of one complex overlap those of another
# NB This superposes $other into frame of reference of $self
# TODO DES this is, but shouldn't be, specific to Domain::CofM here
sub overlap {
    my ($self, $other) = @_;
    # First superpose:
    # The transformation required to put $other into fram-of-reference of $self
    my ($minrmsd, $mintrans, $minname) = $self->min_rmsd($other);
    return unless defined $mintrans;
    $other->transform($mintrans);

    my @cnames = intersection([$self->names], [$other->names]);
    # Weight by min radius of the corresponding domains
    my %weights = map { $_ => min($self->model($_)->radius(), 
                                  $other->model($_)->radius()) } @cnames;
    my $maxweight = sum(values %weights);
    my $overlaps = [];
    foreach my $name (@cnames) {
        my $selfdom = $self->model($name);
        my $otherdom = $other->model($name);
        # The fraction of the maximum possibe overlap between the two
        # Weighted by (min) radius of corresponding domains

# TODO BUG the weighting is somehow broken
#         my $fracoverlap = 
#             $selfdom->evaluate($otherdom) * $weights{$name} / $maxweight;
        my $fracoverlap = $selfdom->evaluate($otherdom);
        $overlaps->push($fracoverlap);
        $logger->debug($name, " (weighted?) fractional overlap: ", $fracoverlap);
    }
    # undo transformation here
    $other->transform($mintrans->inverse);
    return $overlaps->mean;
    
}


################################################################################
=head2 complexrmsd

 Function: RMSD of entire model vs. the corresponding subset of the native
 Example : 
 Returns : RMSD between the complexes
 Args    : 

The second complex will be considered the reference. Only the components having
the same name as those in the first complex will be used. E.g. comparing a dimer
to a tetramer, the second complex will be reduced to the dimer corresponding to
the components in the dimer. They must have the same names.

NB This only works when the corresponding complexes are very similar to each
other.

TODO BUG Since the names of the components may not be the same, this does not
enforce a component mapping as it should. I.e. if the domains are output in a
different order, a superposition may not seem possible, though it may be
possible if output in the proper order.

=cut
sub complexrmsd {
    my ($model, $truth) = @_;
    _init_tmp();

    # Subset $truth . Only consider common components
    my @cnames = intersection([$model->names], [$truth->names]);
    my $subcomplex = new SBG::Complex;

    # Take the original doms from the native complex, if correspondance in model
#     $subcomplex->model($_, $truth->model($_)) for @cnames;
    # Just use the whole true complex, in case component names are different
    # NB this may ruin the order in which domains are output
    $subcomplex = $truth;

    $logger->debug($model->names->length, " and ", $truth->names->length,
                   " components. ", scalar(@cnames), " in common");

    # transform -g both into single PDB files
    my $modelpdbio = new File::Temp;
    my $modelpdb = $model->gtransform(out=>$modelpdbio->filename);
    my $subcomplexpdbio = new File::Temp;
    my $subcomplexpdb = $subcomplex->gtransform(out=>$subcomplexpdbio->filename);

    # Create two domain files, with descriptor { ALL }
    my $model_fh = new File::Temp(
        "complexrmsdXXXX", SUFFIX=>'.dom');
    my $model_dom = $model_fh->filename;
    print $model_fh "$modelpdb 9abc-model { ALL }\n";
    $model_fh->flush;
    my $subcomplex_fh = new File::Temp(
        "complexrmsdXXXX", SUFFIX=>'.dom');
    my $subcomplex_dom = $subcomplex_fh->filename;
    print $subcomplex_fh "$subcomplexpdb 9xyz-subcomplex { ALL }\n";
    $subcomplex_fh->flush;

    my $modelio = SBG::DomainIO->new(
        file=>$model_dom, type=>'SBG::Domain');
    my $modelasdom = $modelio->read;
    my $subcomplexio = SBG::DomainIO->new(
        file=>$subcomplex_dom, type=>'SBG::Domain');
    my $subcomplexasdom = $subcomplexio->read;

    # Don't cache this transform, because these aren't real: 9abc and 9xyz
    my $trans = SBG::STAMP::superpose(
        $subcomplexasdom, $modelasdom, ('cache'=>0));
    $subcomplexasdom->transform($trans);

    return SBG::STAMP::gtransform(
        doms=>[$modelasdom, $subcomplexasdom], out=>'transformed.pdb');

    # Alternatively, get the RMSD
    # Run stamp, model is the query, subcomplex is the database
    my $just1 = 1; # Get the whole set of values back from the first scan
    my $fields = SBG::STAMP::stamp($model_dom, $subcomplex_dom, $just1);
    return unless $fields;

    $logger->trace("RMSD:", $fields->{'RMS'});
    return $fields->{'RMS'};
}


################################################################################
=head2 rmsd

 Function:
 Example :
 Returns : 
 Args    :

RMSD between centres-of-mass from this complex and those of another complex.

Domains are associated by name. Domains present in one complex but not the other
are not considered.

Undefined when no common template domains.

=cut
sub rmsd {
   my ($self,$other) = @_;
   # Only consider common components
   my @cnames = intersection([$self->names], [$other->names]);
   # squared distances between corresponding components
   my $sqdistances = [];
   foreach my $name (@cnames) {
       my $d1 = $self->model($name);
       my $d2 = $other->model($name);

# TODO Subclass Complex !

       # centre-based version
#        $sqdistances->push($d1->sqdist($d2));

       # crosshair-based version( list() converts PDL to Perl array)
       $sqdistances->push($d1->sqdev($d2)->list);

   }
   my $mean = $sqdistances->mean;
   return unless $mean;
   return sqrt($mean);
}


################################################################################
__PACKAGE__->meta->make_immutable;
1;

