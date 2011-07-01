#!/usr/bin/env perl

=head1 NAME

SBG::InteractionIO::html - 

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::IOI>

=cut

################################################################################

package SBG::InteractionIO::html;
use Moose;

with qw/
SBG::IOI
/;



use Carp;
use CGI qw/th Tr td start_table end_table h2/;
use SBG::U::List qw/flatten/;
use SBG::U::HTML qw/formattd rcsb/;
use Moose::Autobox;


################################################################################
=head2 write

 Function: 
 Example : 
 Returns : 
 Args    : L<SBG::Interaction> - 




=cut
sub write {
    my ($self, @interactions) = @_;
    my $fh = $self->fh or return;
    @interactions = flatten(@interactions);

    print $fh h2("Interactions"), "\n";
    print $fh start_table({-border=>'1'});
    my $heads = th([qw/irmsd pval A Amodel Aseqid B Bmodel Bseqid/]);

    my $rows = [ $heads ];

    foreach my $iaction (@interactions) {
        my $keys = $iaction->keys;
        next unless $keys->length;
        my $row = [];
        my $models = $keys->map(sub { $iaction->models->at($_) });
        my $ids = $models->map(sub { $_->subject->id });
        my $seqids = $models->map(sub { $_->scores->at('seqid') });
        my $rcsbs = $ids->map(sub{rcsb($_)});

        push @$row, formattd($iaction->scores->at('irmsd'));
        push @$row, formattd($iaction->scores->at('pval'));

        push @$row, formattd($keys->[0]);
        push @$row, formattd($rcsbs->[0]);
        push @$row, formattd($seqids->[0]);

        push @$row, formattd($keys->[1]);
        push @$row, formattd($rcsbs->[1]);
        push @$row, formattd($seqids->[1]);
        push @$rows, join(' ', @$row);

    }
    print $fh Tr($rows);
    print $fh end_table();

    return $self;
} # write


################################################################################
=head2 read

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub read {
    my ($self) = @_;
    carp "Not implemented";
    return;
}


################################################################################
__PACKAGE__->meta->make_immutable;
no Moose;
1;
