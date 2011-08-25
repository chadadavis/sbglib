#!/usr/bin/env perl

=head1 NAME

B<crystal-conact.pl> - Mark a trans_3_0.contact entry as 'crystal' contact

=head1 SYNOPSIS

# Sets any contact between E or F to any of A B C D as a crystal contact.
# Any contacts E to F or A to B, for example, are not modified

 crystal-contacts.pl 1til 'E F' 'A B C D'

=head1 DESCRIPTION

crystal-contact.pl <pdbid> <chain_id> <chain_id>

Any contacts found between the two chains are marked as crystal contacts.

The PDB ID is not case-sensitive.

The chain IDs are case sensitive.


=head1 OPTIONS

=head2 -h|elp Print this help page

=head2 -l|og Set logging level

In increasing order: TRACE DEBUG INFO WARN ERROR FATAL

I.e. setting B<-l WARN> (the default) will log warnings errors and fatal
messages, but no info or debug messages to the log file (B<log.log>)

=head2 -f|ile Log file

Default: <network name>.log in current directory


=head1 SEE ALSO

L<SBG::DB::contact> , L<SBG::DB::entity> 

=cut

use strict;
use warnings;
use Carp;
use Pod::Usage;
use Log::Any qw/$log/;
use Data::Dumper;
use Moose::Autobox;

# Local libraries
use FindBin qw/$Bin/;
use lib "$Bin/../lib/";

use SBG::U::Run qw/getoptions/;
use SBG::U::DB qw/connect/;
use SBG::U::List qw/pairs2/;

our $dbname = 'trans_3_0';

my %ops = getoptions();

my ($pdbid, $chain1, $chain2) = @ARGV;
unless (defined $chain2) { pod2usage(-exitval => 1, -verbose => 2); }

# Setup new log file specific to given input file
use Log::Any::Adapter;
Log::Any::Adapter->set('+SBG::U::Log', file => $pdbid . '.log');

my @chains1 = split ' ', $chain1;
my @chains2 = split ' ', $chain2;

# All pair of something from first set with something from second sety
my @pairs = pairs2(\@chains1, \@chains2);

foreach my $pair (@pairs) {
    my ($chain1, $chain2) = @$pair;
    crystal_contact($pdbid, $chain1, $chain2);
}

exit;

sub crystal_contact {
    my ($pdbid, $chain1, $chain2) = @_;

    print "$chain1--$chain2: ";

    # Bug makes this necessary, otherwise SELECT after UPDATE fails
    existing_contacts(@_);

    my $nupdated = 0;

    # Both of these approaches appear to work
    $nupdated += set_crystal($pdbid, $chain1, $chain2);

    #     $nupdated += set_crystal_do($pdbid, $chain1, $chain2);

    print "$nupdated rows\n";

    print_contacts($pdbid, $chain1, $chain2);
    print_contacts($pdbid, $chain2, $chain1);

}

sub print_contacts {
    while (my $row = existing_contacts(@_)) {
        my $values =
            $row->slice([qw/crystal id_entity1 id_entity2 dom1 dom2/]);
        print $values->join("\t"), "\n";
    }
}

sub set_crystal_do {
    my ($pdbid, $chain1, $chain2) = @_;

    our $dbh;
    $dbh ||= connect($dbname, undef, undef, $ENV{USER}, 1);

    my $sql = "
update entity e1, contact c, entity e2 
set crystal=1 
where e1.id=c.id_entity1 AND e2.id=c.id_entity2 
AND e1.idcode='$pdbid'
AND e1.chain='$chain1' 
AND e2.chain='$chain2'
";

    print STDERR $sql;
    my $nupdated = $dbh->do($sql);
    return $nupdated;
}

sub set_crystal {
    my ($pdbid, $chain1, $chain2) = @_;

    our $dbh;
    $dbh ||= connect($dbname, undef, undef, $ENV{USER}, 1);
    our $sth;
    $sth ||= $dbh->prepare("
UPDATE
entity e1, contact c, entity e2 
SET
c.crystal=1
WHERE 
e1.id=c.id_entity1 AND e2.id=c.id_entity2 
AND e1.idcode=? 
AND e1.chain=? 
AND e2.chain=?
");

    unless ($sth) {
        $log->error($dbh->errstr);
        return;
    }

    my $nupdated = $sth->execute($pdbid, $chain1, $chain2);
    return $nupdated;
}

sub existing_contacts {
    my ($pdbid, $chain1, $chain2) = @_;

    our $dbh;
    $dbh ||= connect($dbname, undef, undef, $ENV{USER}, 1);
    our $sth;

    if ($sth && $sth->{Active}) {
        return $sth->fetchrow_hashref;
    }

    $sth ||= $dbh->prepare("
SELECT 
e1.idcode, e1.dom as dom1, e2.dom as dom2,
e1.chain as chain1, e2.chain as chain2, 
c.id_entity1, c.id_entity2, c.crystal 
FROM 
entity e1, contact c, entity e2 
WHERE 
e1.id=c.id_entity1 AND e2.id=c.id_entity2 
AND e1.idcode=? 
AND e1.chain=? 
AND e2.chain=?
");

    unless ($sth) {
        $log->error($dbh->errstr);
        return;
    }

    # Iterator semantics
    if (!$sth->execute($pdbid, $chain1, $chain2)) {
        $log->error($sth->errstr);
        return;
    }

    return $sth->fetchrow_hashref();

}

