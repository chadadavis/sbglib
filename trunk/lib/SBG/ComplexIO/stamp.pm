#!/usr/bin/env perl

=head1 NAME

SBG::ComplexIO::stamp - 

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::DomainIO::stamp> , L<SBG::Complex>

=cut

package SBG::ComplexIO::stamp;
use Moose;

with 'SBG::IOI';

use Carp;

use Moose::Autobox;

use SBG::DomainIO::stamp;
use SBG::Model;
use SBG::Complex;
use SBG::ComplexIO::report;
use SBG::Run::cofm qw/cofm/;

=head2 native

 Function: Prevents writing the L<SBG::TransformI> of the domain
 Example : 
 Returns : Bool
 Args    : Bool
 Default : 0 (i.e. any transformation is printed by default)


=cut

has 'native' => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

=head2 objtype

The sub-objtype to use for any dynamically created objects. Should implement
L<SBG::DomainI> role. Default "L<SBG::Domain>" .

=cut

# has '+objtype' => (
#     default => 'SBG::Domain',
#     );

sub BUILD {
    my ($self) = @_;
    $self->objtype('SBG::Domain') unless $self->objtype;
}

=head2 write

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut

sub write {
    my ($self, $complex) = @_;
    return unless defined $complex;
    my $fh = $self->fh or return;

    my $report;
    my $reportio = SBG::ComplexIO::report->new(string => \$report);
    $reportio->write($complex);
    $reportio->close;

    # Prepend a comment
    $report =~ s/^/% /gm;

    print $fh $report;

    # Just delegate all domains in the complex to DomainIO::stamp
    my $io = SBG::DomainIO::stamp->new(fh => $fh);
    $io->write($complex->domains->flatten);

    return $self;
}    # write

=head2 read

 Title   : 
 Usage   : 
 Function: 
 Example : 
 Returns : 
 Args    : 

=cut

sub read {
    my ($self) = @_;
    my $fh = $self->fh or return;

    my $io = SBG::DomainIO::stamp->new(fh => $fh, objtype => $self->objtype);
    my $doms = $io->read_all;
    my $spheres = $doms->map(sub { cofm($_) });
    my $models =
        $spheres->map(sub { SBG::Model->new(query => $_, subject => $_) });
    my $complex = SBG::Complex->new;
    $models->map(sub { $complex->add_model($_) });

    my $contacts = $complex->contacts();
    foreach my $contact ($contacts->flatten) {
        $complex->interactions->put($contact, $contact);
    }

    return $complex;

}    # read

__PACKAGE__->meta->make_immutable;
no Moose;
1;
