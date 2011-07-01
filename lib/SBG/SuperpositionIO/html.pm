#!/usr/bin/env perl

=head1 NAME

SBG::SuperpositionIO::html - 

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::IOI>

=cut



package SBG::SuperpositionIO::html;
use Moose;

with qw/
SBG::IOI
/;



use Carp;
use CGI qw/th Tr td start_table end_table h2/;
use SBG::U::List qw/flatten/;
use SBG::U::HTML qw/formattd/;
use Moose::Autobox;



=head2 write

 Function: 
 Example : 
 Returns : 
 Args    : L<SBG::Superposition> - 




=cut
sub write {
    my ($self, @superpositions) = @_;
    my $fh = $self->fh or return;
    @superpositions = flatten(@superpositions);

    print $fh h2("Superpositions"), "\n";
    print $fh start_table({-border=>'1'});
    my $heads = th([qw/from to Sc RMS nfit seq_id/]);

    my $rows = [ $heads ];

    foreach my $superpos (@superpositions) {

        my $row = [];

        push @$row, formattd($superpos->from->id);
        push @$row, formattd($superpos->to->id);

        push @$row, formattd($superpos->scores->at('Sc'));
        push @$row, formattd($superpos->scores->at('RMS'));
        push @$row, formattd($superpos->scores->at('nfit'));
        push @$row, formattd($superpos->scores->at('seq_id'));

        push @$rows, join(' ', @$row);

    }
    print $fh Tr($rows);
    print $fh end_table();

    return $self;
} # write



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



__PACKAGE__->meta->make_immutable;
no Moose;
1;
