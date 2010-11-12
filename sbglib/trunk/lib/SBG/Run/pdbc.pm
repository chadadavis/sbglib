#!/usr/bin/env perl

=head1 NAME

SBG::Run::pdbc - Wrapper for running B<pdbc> (to get entry/chain descriptions


=head1 SYNOPSIS

 use SBG::Run::pdbc qw/pdbc/;

 my $templates = '1g3nAC';
 my $pdbc = pdbc($templates);
 print 'Annotation for chain A : ', $pdbc->{chain}{A};
 print 'Annotation for whole complex : ', $pdbc->{header};
 
=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::DomainI>

=cut



package SBG::Run::pdbc;
use base qw/Exporter/;
our @EXPORT_OK = qw/pdbc/;

use Moose::Autobox;
use Log::Any qw/$log/;

use SBG::Types qw/$pdb41/;



=head2 pdbc

 Function: 
 Example : 
 Returns : Hash
 Args    : L<SBG::DomainI>


B<pdbc> must be in your PATH

=cut
sub pdbc {
    my ($str) = @_;
    $log->debug($str);
    our %cache;

    my ($pdb, $chains) = $str =~ /^(\d\w{3})(.*)?/;
    # Get struture for entire PDB entry, if not already fetched
    $cache{$pdb} ||= _run($pdb);
    my $cached = $cache{$pdb};
    return $cached unless $chains;
    # But only provide chain information for given chains
    my @chains = split '', $chains;
    # Copy
    my $subcomplex = { %$cached };
    # Remove an copied chains
    $subcomplex->{chain} = {};
    # Add only requested chains
    $subcomplex->{chain}{$_} = $cached->{chain}{$_} for @chains;
    return $subcomplex;

} # pdbc





sub _run {
    my ($pdb, ) = @_;
    open my $pdbcfh, "pdbc -d ${pdb}|";
    # Process header first
    my $header = _header($pdbcfh, $pdb);
    # Suck up other chains
    my %fields = _chains($pdbcfh);
    # Add the header in
    my $h = { pdbid=>$pdb, header=>$header, chain=>{%fields} };
    return $h;
}


sub _header {
    my ($pdbcfh, $pdb) = @_;
    
    my $first = <$pdbcfh>;
    my@fields = split ' ', $first;
    # Remove leading comment
    shift @fields if $fields[0] eq '%';
    # Remove date and entry 24-OCT-00   1G3N
    pop @fields if $fields[$#fields] eq uc($pdb);
    pop @fields if $fields[$#fields] =~ /\d{2}-[A-Z]{3}-\d{2}/;
    # Concate the rest back together
    my $desc = join(' ', @fields);
    return $desc;
}

sub _chains {
    my ($pdbcfh,) = @_;
    my %chain2desc;
    while (my $line = <$pdbcfh>) {
        my ($mol) = $line =~ /MOLECULE:\s*(.*)/;
        next unless $mol;
        $mol =~ s/;? +$//g;
        $line = <$pdbcfh>;        
        my ($chains) = $line =~ /CHAIN:\s*(.*)/;
        $chains =~ s/[^A-Z0-9a-z]//g;
        my @chains = split '', $chains;
        $chain2desc{$_} = $mol for @chains;
    }
    return %chain2desc;
}

1;
