#!/usr/bin/env perl

=head1 NAME

SBG::Run::pdbc - Wrapper for running B<pdbc> (to get entry/chain descriptions


=head1 SYNOPSIS

 use SBG::Run::pdbc qw/pdbc/;

 my $dom = new SBG::DomainI(pdbid=>'2nn6', descriptor=>'A 13 _ to A 331 _');
 my %fields = pdbc($dom);
 print "Entry description:", $fields{'header'};
 print "Chain A description:", $fields{'A'};

=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::DomainI>

=cut

################################################################################

package SBG::Run::pdbc;
use base qw/Exporter/;
our @EXPORT_OK = qw/pdbc/;


use SBG::Types qw/$pdb41/;

################################################################################
=head2 pdbc

 Function: 
 Example : 
 Returns : Hash
 Args    : L<SBG::DomainI>


B<pdbc> must be in your PATH

=cut
sub pdbc {
    my ($str) = @_;
    our %cache;

    my ($pdb, $chain) = $str =~ /^(\d\w{3})(.)?/;
    $cache{$pdb} ||= _run($pdb);
    return $cache{$pdb};

} # pdbc


sub _run {
    my ($pdb, ) = @_;
    open my $pdbcfh, "pdbc -d ${pdb}|";
    # Process header first
    my $header = _header($pdbcfh, $pdb);
    # Suck up other chains
    my %fields = _chains($pdbcfh);
    # Add the header in
    $fields{'header'} = $header;    
    return \%fields;
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
    my $slurp = join('', <$pdbcfh>);
    while ($slurp =~ /MOLECULE:\s*(.*?);.*?CHAIN:\s*(.)/gms) {
        $chain2desc{$2} = $1;
    }
    return %chain2desc;
}
	


################################################################################
1;
