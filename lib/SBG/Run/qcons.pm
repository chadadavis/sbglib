#!/usr/bin/env perl

=head1 NAME

SBG::Run::qcons - Wrapper for running B<Qcontacts> (residue contacts)


=head1 SYNOPSIS


=head1 DESCRIPTION

This is a small wrapper for running Qcontacts:

 http://tsailab.tamu.edu/QCons/

It makes use of another wrapper: L<Bio::Tools::Run::Qcons> which is available on Github at:

 https://github.com/brunoV/qcons

An additional wrapper is necessary, because Qcons only processes entire
chains. Furthermore, if a structure has been transformed, a new PDB file must
created. Finally, Qcons does not process gzipped files. So, even if a
structure hasn't been transformed or truncated, it at least needs to be
unzipped.

=head1 SEE ALSO

=over 4

=item L<Bio::Tools::Run::Qcons>

=item L<SBG::DomainIO::pdb>

=back

=cut

package SBG::Run::qcons;
use strict;
use warnings;
use base qw/Exporter/;
our @EXPORT_OK = qw/qcons/;

use Cwd;
use File::Basename;
use Log::Any qw/$log/;

use Bio::Tools::Run::QCons;
# Autobox Has to be loaded after Mouse (used by Qcons)
use Moose::Autobox;

use SBG::DomainIO::pdb;
use SBG::Interaction;
use SBG::Model;
use SBG::U::List qw/pairs flatten/;
use SBG::Cache qw(cache);

#use Devel::Comments;

=head2 qcons

 Function: 
 Example : 
 Returns : 
 Args    : 

If multiple Domains are provided, qcons is run on all pairs of domains.

TODO save n_res, total, and on each side

=cut

sub qcons {
    my @doms = flatten(@_);
    $log->debug(scalar(@doms), " domains: @doms");
    my $io = SBG::DomainIO::pdb->new(tempfile => 1, suffix => '.pdb');
    $io->write(@doms);
    $io->close;
    my $file = $io->file;

    # Map domain names to the chain that they have been written to
    my %domainmap;
    for (my ($i, $chain) = (0, 'A'); $i < @doms; $i++, $chain++) {
        $domainmap{ $doms[$i] } = $chain;
    }
    my $ndoms = @doms;

    my $cache = cache();
    my $contacts = [];
    foreach my $pair (pairs(@doms)) {
        my $key = join '--', map { $_->hash } @$pair;
        ### $key
        my $res_contacts = $cache->get($key);
        ### cached : $res_contacts

        if (! defined $res_contacts) {
            $log->debug("Running QCons on pair @$pair");
            my $chains = $pair->map(sub { $domainmap{$_} });
            my $qcons =
                Bio::Tools::Run::QCons->new(file => $file, chains => $chains);
            # Summarize by residue (rather than by atom)
            $res_contacts = $qcons->residue_contacts;
            $cache->set($key, $res_contacts);
            ### caching : $res_contacts
        }

        next unless ($res_contacts->length);

        # Count residues in contact, by chain
        my %contacts1;
        my %contacts2;
        foreach my $contact ($res_contacts->flatten) {
            $contacts1{ $contact->{res1}{number} }++;
            $contacts2{ $contact->{res2}{number} }++;
        }

        my $n_res1 = keys %contacts1;
        my $n_res2 = keys %contacts2;

        $log->debug("@$pair : $n_res1 residues in contact with $n_res2");

        my $interaction = SBG::Interaction->new;
        $interaction->set(
            $pair->[0],
            SBG::Model->new(
                subject => $pair->[0],
                scores  => { 'n_res' => $n_res1 }
            )
        );

        $interaction->set(
            $pair->[1],
            SBG::Model->new(
                subject => $pair->[1],
                scores  => { 'n_res' => $n_res2 }
            )
        );

        $contacts->push($interaction);
    }

    return $contacts;

}    # qcons

1;
__END__
