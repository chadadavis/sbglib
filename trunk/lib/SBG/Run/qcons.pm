#!/usr/bin/env perl

=head1 NAME

SBG::Run::qcons - Wrapper for running B<Qcontacts> (residue contacts)


=head1 SYNOPSIS


=head1 DESCRIPTION

=head1 SEE ALSO

L<SBG::DomainIO::pdb>

=cut


package SBG::Run::qcons;
use base qw/Exporter/;
our @EXPORT_OK = qw/qcons/;

use Cwd;
use File::Basename;
use Log::Any qw/$log/;
use Moose::Autobox;

use Bio::Tools::Run::QCons;
use SBG::DomainIO::pdb;
use SBG::Interaction;
use SBG::Model;
use SBG::U::List qw/pairs flatten/;


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
    my $io = SBG::DomainIO::pdb->new(tempfile=>1, suffix=>'.pdb');
    $io->write(@doms);
    $io->close;
    my $file = $io->file;

    # Map domain names to the chain that they have been written to
    my %domainmap;
    for (my $i = 0, $chain = 'A'; $i < @doms; $i++, $chain++) {
        $domainmap{$doms[$i]} = $chain;
    } 
    my $ndoms = @doms; 

    my $contacts = [];    
    foreach my $pair (pairs(@doms)) {
        my $chains = $pair->map(sub{$domainmap{$_}});
        $log->debug("Running QCons on pair @$pair");
        
        my $qcons = Bio::Tools::Run::QCons->new(file=>$file, chains=>$chains);
    
        # Summarize by residue (rather than by atom)
        my $res_contacts = $qcons->residue_contacts;
        next unless ($res_contacts->length);

        # Count residues in contact, by chain
        my %contacts1;
        my %contacts2;
        foreach my $contact ($res_contacts->flatten) {
            $contacts1{$contact->{'res1'}{'number'}}++;
            $contacts2{$contact->{'res2'}{'number'}}++;
        }
        my $n_res1 = keys %contacts1;
        my $n_res2 = keys %contacts2;

        $log->debug("@$pair : $n_res1 residues in contact with $n_res2");
                
        my $interaction = SBG::Interaction->new;
        $interaction->set($pair->[0], 
            SBG::Model->new(subject=>$pair->[0],scores=>{'n_res'=>$n_res1}));
        $interaction->set($pair->[1], 
            SBG::Model->new(subject=>$pair->[1],scores=>{'n_res'=>$n_res2}));
        $contacts->push($interaction);
    }
    return $contacts;
} # qcons


1;
__END__
