#!/usr/bin/env perl

=head1 NAME

SBG::InteractionIO - 

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::IO>

=cut

################################################################################

package SBG::IneractionIO;
use SBG::Root -base, -XXX;
use base qw(SBG::IO);

use warnings;
use Carp;

use SBG::Interaction;



################################################################################

sub new () {
    my $class = shift;
    # Delegate to parent class
    my $self = new SBG::IO(@_);
    # And add our ISA spec
    bless $self, $class;
    return $self;
} # new


################################################################################
=head2 read

 Title   : read
 Usage   : my $iaction = $io->read();
 Function: Reads the next interaction line from the stream
 Example : (see below)
 Returns : An L<SBG::Interaction>
 Args    : NA

 # Read all Interaction lines from a CSV file
 my @iactions;
 while (my $iactino = $io->read) {
     push @iactions, $dom;
 }
 print "Read in " . scalar(@iactions) . " Interactions\n";

TODO Test errors from split()

TODO How to read off two accessions and then pass on to DomainIO?

=cut
sub read {
    my $self = shift;
    my $fh = $self->fh;

    # Save the nodes we have already created, so as not to duplicate
    our %nodes;

    # TODO need DomainIO here !
    while (<$fh>) {
        chomp;
        # Comments and blank lines
        next if /^\s*\#/;
        next if /^\s*\%/;
        next if /^\s*$/;

        # How about:
        # Remember filename may be blank ...
        # comp1 comp2 file1 label1 { ... } file2 label2 { ... } score


        # TODO need DomainIO here !
        my ($comp_a, $comp_b, $templ_a, $templ_b, $score) = split /\s+/;

        print STDERR "iaction: $_\n", 

        # Create network nodes from sequences. Sequences from accession_number
        $nodes{$comp_a} ||= 
            new SBG::Node(new SBG::Seq(-accession_number=>$comp_a));
        $nodes{$comp_b} ||= 
            new SBG::Node(new SBG::Seq(-accession_number=>$comp_b));

        # TODO save a Template obj in Interaction?
        # Since that's exactly what it represents

        # create new Interaction object based on an id and weight
        # NB the ID must be unique in the whole graph
        my $interaction = Bio::Network::Interaction->new(
            -id => "${comp_a}-${comp_b}(${templ_a}-${templ_b})",
            -weight => $score,
            );

        # Add a dictionary to lookup which domain is model for which component
        $interaction->{template} = { 
            $comp_a => $templ_a, $comp_b => $templ_b,
        };






        # Create/parse new domain header
        unless (/^(\S+)\s+(\S+)\s+\{ ([^}]+)\s+/) {
            carp "Cannot parse:$_:\n";
            return undef;
        }

        my $dom = new SBG::Domain();
        $dom->file($1);
        $dom->file2pdbid(); # Parses out PDB ID from filename
        $dom->stampid($2);
        $dom->descriptor($3);

        # Header ends, i.e. contains no transformation
        if (/\}\s*$/) { 
            return $dom;
        }

        # Parse transformtion
        my $transstr = $self->_read_trans;
        my $trans = new SBG::Transform(-string=>$transstr);
        $dom->transformation($trans);
        return $dom;
    }
    # End of file
    return undef;
} # read




# TODO DES modify to read STAMP descriptors
# TODO DES define a common text format for an 'interaction template'
# Returns L<SBG::Network>
# TODO one line might contain multiple templates for modelling single interaction
# Need to loop over those and add them too
sub read_templates {
    my ($file) = @_;

    my $io = SBG::IO->new(-file => $file);
    # Save the nodes we have already created, so as not to duplicate
    my %nodes;

    while (my $l = $io->read() ) {
        # Skip comments/blank lines
        next if ($l =~ /^\s*$/ || $l =~ /^\s*#/ || $l =~ /^\s*%/);
        my ($comp_a, $comp_b, $templ_a, $templ_b, $score) = split(/\s+/, $l);
        print STDERR "iaction: $l\n", 
        

        # Create network nodes from sequences. Sequences from accession_number
        $nodes{$comp_a} ||= 
            new Bio::Network::Node(new Bio::Seq(-accession_number=>$comp_a));
        $nodes{$comp_b} ||= 
            new Bio::Network::Node(new Bio::Seq(-accession_number=>$comp_b));

        # TODO save a Template obj in Interaction?
        # Since that's exactly what it represents

        # create new Interaction object based on an id and weight
        # NB the ID must be unique in the whole graph
        my $interaction = Bio::Network::Interaction->new(
            -id => "${comp_a}-${comp_b}(${templ_a}-${templ_b})",
            -weight => $score,
            );

        # Add a dictionary to lookup which domain is model for which component
        $interaction->{template} = { 
            $comp_a => $templ_a, $comp_b => $templ_b,
        };

        # TODO Trying to get GraphViz to display edge labels ...
#         $interaction->{'label'} = $interaction->primary_id;

#         print STDERR 
#             "Adding: $comp_a, $comp_b via ", $interaction->primary_id, "\n";

        $graph->add_interaction(
#             -nodes => [($prot1,$prot2)],
#             -nodes => [($components{$comp_a}, $components{$comp_b})], 
#             -nodes => [$components{$comp_a}, $components{$comp_b}], 
            -nodes => [$nodes{$comp_a}, $nodes{$comp_b}], 
            -interaction => $interaction,
            );
    }

    return $graph;
} # read_templates


################################################################################
1;
