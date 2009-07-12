#!/usr/bin/env perl

=head1 NAME

SBG::InteractionIO::csv - 

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::IOI>

=cut

################################################################################

package SBG::InteractionIO::csv
use Moose;

with 'SBG::IOI';


use SBG::Interaction;


################################################################################
=head2 write

 Function: tab-separated line of components and their templates 
 Example : $output->write($interaction);
 Returns : $self
 Args    : L<SBG::Interaction> - 

RRP41 RRP42  2br2 { A 108 _ to A 148 _ } 2br2 { D 108 _ to D 148 _ } 


=cut
sub write {
    my ($self, @interactions) = @_;

    my $fh = $self->fh or return;
    foreach my $iaction (@interactions) {
        my ($node1, $node2) = sort $iaction->nodes;
        my ($model1, $model2) = map { $iaction->at($_) } ($node1, $node2);
        my ($pdb1, $pdb2) = map { $_->pdbid } ($model1, $model2);
        my ($descr1, $descr2) = map { $_->descriptor } ($model1, $model2);
        print $fh "$node1\t$node2\t$pdb1\t{ $descr1 }\t$pdb2\t{ $descr2 }";

    }
    return $self;
} # write


################################################################################
=head2 read

 Title   : read
 Usage   : my $interaction = $io->read();
 Function: Reads the next interaction from the stream
 Example : 
 Returns : An L<SBG::Interaction>
 Args    : NA

=cut
sub read {
    my ($self) = @_;
    my $fh = $self->fh or return;
    my @iactions;


    while (my $line = <$fh>) {
        chomp $line;
        # Comments and blank lines
        next if $line =~ /^\s*\%/;
        next if $line =~ /^\s*\#/;
        next if $line =~ /^\s*$/;
        next if $line =~ /^\s*\}/;

        # Create/parse new domain header, May not always have a file name
        unless ($line =~ 
                /^(\S*)\s+($re_pdb)(\S*)\s*\{\s*($re_descriptor)(\s*\})?\s*$/) {
            carp("Cannot parse STAMP domain: $line");
            
            # Want an array of domains, then skip to next one, otherwise abort
            wantarray ? next : last;
        }

        # $1 is (possible) file
        # $2 is pdbid
        # $3 is rest of STAMP label
        # $4 is STAMP descriptor, without { }

        my $type = $self->type();
        my $dom = $type->new(pdbid=>$2,descriptor=>$4);
        $dom->file($1) if $1;

        # Parse transformtion, if any
        # Header ends?, i.e. contains no transformation
        if ($line !~ /\}\s*$/) { 
            my $transio = new SBG::TransformIO::stamp(fh=>$self->fh);
            my $transformation = $transio->read;
            # Since a transformation was found, apply it
            $dom->transform($transformation->matrix);
        }

        push @doms, $dom;

        # Stop the loop unless looking for all domains in the file
        last unless wantarray;
    }
    return wantarray ? @doms : shift @doms;

} # read


################################################################################
__PACKAGE__->meta->make_immutable;
no Moose;
1;
