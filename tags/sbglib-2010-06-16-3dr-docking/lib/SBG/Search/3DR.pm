#!/usr/bin/env perl

=head1 NAME

SBG::Search::Roberto - 

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::SearchI> , L<SBG::Network> , L<SBG::Interaction> 

=cut

package SBG::Search::3DR;
use Moose;
with 'SBG::SearchI';
use Moose::Autobox;

use Log::Any qw/$log/;
use DBI;
use File::Basename;
use Sort::Key::Top qw/rnkeytopsort/;

# Must load SBG::Seq to get string overload on Bio::PrimarySeqI
use SBG::Seq;
use SBG::Domain;
use SBG::Model;
use SBG::Interaction;
use SBG::U::DB;

use SBG::U::List qw/interval_overlap flatten/;


has '_dbh' => ( is => 'rw', );

# Statement handles to query each table, indexed by table name
# Roberto_chain_templates.csv
# Roberto_domain_defs.csv
# Roberto_domain_templates.csv
has '_sth' => (
    is      => 'ro',
    isa     => 'HashRef',
    default => sub { {} },

);


our $datadir = $ENV{'AG'} . '/3DR/data';
        
has 'model_sources' => (
    is => 'rw',
    isa => 'ArrayRef[Str]',
    default => sub { [
    	$datadir . '/modbase/yeast-mp2',
    	$datadir . '/final_paper/roberto/modelling/models_for_single_proteins',
    	] },
    );

     
has 'docking_dir' => (
    is => 'rw',
    isa => 'Str',
    default => $datadir . '/final_paper/roberto/docking/chopped',
    );
        

has 'dbname' => (
    is => 'rw',
    isa => 'Str',
    default => '3dr_complexes',
    );
     

sub BUILD {
    my ($self) = @_;

    my $dbh = SBG::U::DB::connect($self->dbname);

    # TODO invalid state if connection fails (too late, has to be in BUILDARGS)
    return unless defined $dbh;
    $self->_dbh($dbh);

    # Stored unidirectionally (uniprot1 < uniprot2)
    my $sth_interaction = $dbh->prepare(
        join ' ', 
        'SELECT',
        '*', 
        'FROM',
        'interaction_templates_v3',
        'WHERE',
        'uniprot1=? AND uniprot2=?',
        # Don't take results where interprets failed
        'AND status not like "%failed"',
        # Necessary for other cases where it effectively failed
        'AND sd > 0',
    );
    $self->_sth->put('interaction_templates', $sth_interaction );

    my $sth_docking = $dbh->prepare(
        join ' ',
        'SELECT',
        '*',
        'FROM',
        'docking_templates',
        'WHERE (uniprot1=? AND uniprot2=?)',
        'AND class != "incorrect"',
        # Take HC first, then clas 'HIGH', then highest score
        'order by hc desc, class asc, score desc',
        
    );
    $self->_sth->put('docking_templates', $sth_docking);

    return $self;
} # BUILD


=head2 search

 Function: 
 Example : 
 Returns : 
 Args    : Two L<Bio::Seq>


=cut

sub search {
    my ( $self, $seq1, $seq2, %ops ) = @_;

    # Need to query in both directions? No, smallest first
    # This is the case for the interaction_templates, using uniprot
    
    # TODO after converting sgd to uniprot, won't be the case for docking ...
    ( $seq1, $seq2 ) =
      sort { $a->display_id cmp $b->display_id } ( $seq1, $seq2 );

    my @interactions;
    push @interactions, $self->_interactions( $seq1, $seq2, %ops );

    my $topn = $ops{'top'};

    # Only use docking-based templates where there weren't enough chain-based
    unless ( $topn && scalar(@interactions) >= $topn ) {
        push @interactions, $self->_docking( $seq1, $seq2, %ops );
        # Query in both directions
        push @interactions, $self->_docking( $seq2, $seq1, %ops );
    }

    if ($topn) {

        # Take top N interactions
        # This is the reverse numerical sort on the weight field
        @interactions = rnkeytopsort { $_->weight } $topn => @interactions;
    }
    $log->debug( scalar(@interactions), " interactions ($seq1,$seq2)" );

    # Superpose structure (or Modbase model) onto template interactions
    # I.e. the native structure is now the template. The interaction template
    # simply serves to define the relative orientations.
    @interactions = map { $self->_structures($_) } @interactions;
    
    return @interactions;
}    # search


# Matt's interaction summary: structures
sub _interactions {
    my ( $self, $seq1, $seq2, %ops ) = @_;

    my $sth = $self->_sth->at('interaction_templates');
    my $res = $sth->execute( $seq1->display_id, $seq2->display_id );
        
    my @interactions;
    while ( my $h = $sth->fetchrow_hashref ) {

        # Check sequence coverage
        next unless _covers($seq1, $h->{start1}, $h->{end1}, %ops);
        next unless _covers($seq2, $h->{start2}, $h->{end2}, %ops);
        
        my $dom1 = _mkdom( $h->slice( [qw/pdbid assembly model1 dom1/] ) );
        my $dom2 = _mkdom( $h->slice( [qw/pdbid assembly model2 dom2/] ) );

        my $mod1 = SBG::Model->new(
            query   => $seq1,
            input   => $seq1,
            subject => $dom1,
            scores  => { seqid => $h->{pcid1}, n_res => $h->{n_res1} },
        );
        my $mod2 = SBG::Model->new(
            query   => $seq2,
            input   => $seq2,
            subject => $dom2,
            scores  => { seqid => $h->{pcid2}, n_res => $h->{n_res2} },
        );

        my $iaction = SBG::Interaction->new(source=>$h->{source});
        $iaction->set( $seq1, $mod1 );
        $iaction->set( $seq2, $mod2 );
        $iaction->avg_scores(qw/seqid n_res/);
        
        my $avg_seqid = $iaction->scores->at('avg_seqid');
        $log->debug("avg_seqid $avg_seqid");

        # Scale to n_res to [0:100] (assuming max interface size of 1000
        my $avg_n_res = $iaction->scores->at('avg_n_res') / 10;
        $log->debug("avg_n_res $avg_n_res");

        # Save interprets z-score in the interaction
        $iaction->scores->put('interpretsz', $h->{z});
        
        my ( $wtnres, $wtseqid ) = ( .1, .9 );
    
        my $score =
          100 *
          ( $wtnres * $avg_n_res + $wtseqid * $avg_seqid ) /
          ( $wtnres * 100 + $wtseqid * 100 );

        $iaction->weight($score);

        push @interactions, $iaction;
    }
    return @interactions;

} # _interactions


sub _covers {
	my ($seq,$start2, $end2, %ops) = @_;
	
	# If start2 or end2 not defined (the template coverage of the sequence),
	# then assume it's a full-length template
	return 1 unless $start2 && $end2;
	my $start1 = 1;
	my $end1 = $seq->length;
	
	# minumum sequence coverage required
    $ops{'overlap'} = 0.50 unless defined $ops{'overlap'};
	
    # How much of structural fragment covered by sequence
    # And how much of sequence covered by structural fragment
    my ($covered_struct, $covered_seq) = 
        interval_overlap($start1, $end1, $start2, $end2);
            
    if ($covered_struct < $ops{'overlap'} ||
        $covered_seq < $ops{'overlap'} ) { 
        $log->debug("covered_struct: $covered_struct");
        $log->debug("covered_seq: $covered_seq");
        return 0;
    }
        
    return 1;
    	
}


sub _docking {
    my ( $self, $seq1, $seq2 ) = @_;

    my $sth = $self->_sth->at('docking_templates');
    my $res = $sth->execute(
        $seq1->display_id, $seq2->display_id,
    );
    my @interactions;
    while ( my $h = $sth->fetchrow_hashref ) {
    	# Our docking data provides alternative interaction conformations
    	my $dir = join '/', $self->docking_dir, $h->{directory};
    	foreach my $file (<$dir/*>) {
    		
            my $dom1 = SBG::Domain->new(file=>$file,descriptor=>'CHAIN A');
            my $dom2 = SBG::Domain->new(file=>$file,descriptor=>'CHAIN B');
        
            my $mod1 = SBG::Model->new(
                input   => $seq1,
                query   => $seq1,
                subject => $dom1,
                scores  => { type => $h->{type1} },
            );
            my $mod2 = SBG::Model->new(
                input   => $seq2,
                query   => $seq2,
                subject => $dom2,
                scores  => { type => $h->{type2} },
            );

            my $iaction = SBG::Interaction->new(source=>'docking');
            $iaction->set( $seq1, $mod1 );
            $iaction->set( $seq2, $mod2 );
        
            my $score = $h->{score};
            $iaction->scores->put('docking', $score);
            
            # Arbitary weight, to be less than the structure-based templates
            $iaction->weight($score / 1000);

            push @interactions, $iaction;
    	}        
    }
    $log->info("Docking: $interactions[0]") if @interactions;
    return @interactions;

} # _docking


sub _mkdom {
    my ($pdbid, $assembly, $model, $descriptor) = flatten(@_);

    my $dom = SBG::Domain->new(
        pdbid      => $pdbid,
        assembly   => $assembly,
        model      => $model,
        descriptor => $descriptor,
    );
    return $dom;
}


use SBG::Superposition::Cache qw/superposition/;
use SBG::Run::rasmol;
use SBG::Run::cofm qw/cofm/;

sub _structures {
	my ($self, $interaction) = @_;

    # For each half of this binary interaction
    foreach my $key ($interaction->keys->flatten) {
    	my $templ_dom = $interaction->get($key)->subject;
    	# For each source of potential homology models
    	my $best_sc = 0;
    	my $best_struct;
    	my @struct_files;
    	my @sources = $self->model_sources->flatten;
    	push(@struct_files, <${_}/${key}*.pdb>) for @sources;
        $log->debug(scalar(@struct_files), " structures for $key");
        foreach my $struct (@struct_files) {
            	# Representation of the modelled structure
            	my $struct_dom = SBG::Domain->new(file=>$struct);
            	# Represent as a Sphere, 
            	$struct_dom = cofm($struct_dom);
                $log->debug("For $key, trying $struct_dom onto $templ_dom");
                # Superpose the homology model onto the interaction template
                my $superposition = superposition(
                    $struct_dom, $templ_dom);
                next unless defined $superposition;
                # Apply the superposition to the homology model
                $superposition->apply($struct_dom);
                # Note the best
                my $sc = $superposition->scores->at('Sc');
                if ($sc > $best_sc) {
                	$best_sc = $sc;
                	$best_struct = $struct_dom;
                }
        }
        if ($best_struct) {
        	# Given the best structure, put it into the Model, as a reference
            $interaction->get($key)->structure($best_struct);
        }
        
    }
     
    return $interaction;
    	
}


__PACKAGE__->meta->make_immutable;
no Moose;
1;

__END__

