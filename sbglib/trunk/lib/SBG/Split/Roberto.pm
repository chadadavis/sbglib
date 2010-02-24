
#!/usr/bin/env perl

=head1 NAME

SBG::Split::Roberto - Divides a Bio::Seq into domains

=head1 SYNOPSIS



=head1 DESCRIPTION


=head1 SEE ALSO


=cut

################################################################################

package SBG::Split::Roberto;
use Moose;
with 'SBG::SplitI';

use Moose::Autobox;
use Log::Any qw/$log/;

use Bio::Seq;
use DBI;


################################################################################
=head2 csvfile

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
has 'csvdir' => (
    is => 'rw',
    isa => 'Str',
    default => '/g/russell2/3dr/data/final_paper/roberto',
    );


has 'mingap' => (
    is => 'rw',
    isa => 'Int',
    default => 30,
    );


has '_dbh' => (
    is => 'rw',
    );


has '_sth' => (
    is => 'rw',
    );


sub BUILD {
    my ($self) = @_;
    my $f_dir = $self->csvdir;
    my $dbh=DBI->connect("DBI:CSV:f_dir=${f_dir};csv_eol=\n;csv_sep_char=\t");

    my $sth = $dbh->prepare(
	"SELECT " . 
	"PROT DOM E-VALUE ID START END DOM_ID " .
	"FROM yeast_domains.txt where PROT=?"
	);

    $self->_dbh($dbh);
    $self->_sth($sth);
    return $self;
}



################################################################################
=head2 split

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub split {
    my ($self, $seq) = @_;
    my $sth = $self->_sth;

    my $res = $sth->execute($seq->display_id);

    my @boundaries;
    while (my $h = $sth->fetchrow_hashref) {
	# Add start and end of domain to list of potential boundaries
	push @boundaries, $h->{'START'}, $h->{'END'};
    }


    # Smooth boundaries
    @boundaries = $self->_smooth($seq->length, @boundaries);

    # Split seq into subsequences, on boundaries

}


# Smooth/expand the boundaries. 
# No short fragments between domains, nor at begin/end of sequence
sub _smooth {
    my ($self, $end, @boundaries) = @_;

    # If any two boundaries are two close together, collapses them into one
    for (my $i = 0; $i < @boundaries - 1; $i++) {
	# Find the midpoint and delete the previous boundary
	if ($boundaries[$i+1] - $boundaries[$i] < $self->mingap) {
	    $boundaries[$i+1] = int($boundaries[$i]+$boundaries[$i+1])/2;
	    delete $boundaries[$i];
	}
    }

    @boundaries = grep { defined $_ } @boundaries;

    if ($boundaries[0] < $self->mingap) {
	$boundaries[0] = 1;
    } else {
	unshift @boundaries, 1;
    }

    if ($boundaries[-1] > $end - $self->mingap) {
	$boundaries[-1] = $end;
    } else {
	push @boundaries, $end;
    }

    return @boundaries;
}


################################################################################
__PACKAGE__->meta->make_immutable;
no Moose;
1;


