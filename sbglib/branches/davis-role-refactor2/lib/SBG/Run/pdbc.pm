
#!/usr/bin/env perl

=head1 NAME

SBG::Run::pdbc - Wrapper for running B<pdbc>


=head1 SYNOPSIS

 use SBG::Run::pdbc;


=head1 DESCRIPTION


=head1 SEE ALSO


=cut

################################################################################

package SBG::Run::pdbc;
use base qw/Exporter/;
our @EXPORT_OK = qw/pdbc/;

use SBG::DomainIO;
use SBG::U::Log;

################################################################################
=head2 pdbc

 Function: Runs STAMP's pdbc and opens its output as the internal input stream.
 Example : my $domio = pdbc('2nn6');
           my $dom = $domio->read();
           # or all in one:
           my $first_dom = pdbc(pdbid=>'2nn6')->read();
 Returns : $self (success) or undef (failure)
 Args    : @ids - begins with one PDB ID, followed by any number of chain IDs

Depending on the configuration of STAMP, domains may be searched in PQS first.

 my $io = new SBG::DomainIO;
 $io->pdbc('2nn6');
 # Get the first domain (i.e. chain) from 2nn6
 my $dom = $io->read;

=cut
sub pdbc {
    my $str = join("", @_);
    return unless $str;
    my $io = new SBG::DomainIO(tempfile=>1);
    my $path = $io->file;
    my $cmd;
    $cmd = "pdbc -d $str > ${path}";
    $logger->trace($cmd);
    # NB checking system()==0 fails, even when successful
    system($cmd);
    # So, just check that file was written to instead
    unless (-s $path) {
        $logger->error("Failed:\n\t$cmd\n\t$!");
        return 0;
    }
    return $io;

} # pdbc


################################################################################
1;
