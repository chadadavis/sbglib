#!/usr/bin/env perl

=head1 NAME

EMBL::DB - Simple database utilities

=head1 SYNOPSIS

use EMBL::DB;

# Connect to DB
# (This is the actual DBI handle)
my $dbh = dbconnect("pc-russell12", "database_name");

=head1 DESCRIPTION


=head1 BUGS

None known.

=head1 REVISION

$Id: Prediction.pm,v 1.33 2005/02/28 01:34:35 uid1343 Exp $

=head1 APPENDIX

Details on functions implemented here are described below.
Private internal functions are generally preceded with an _

=cut

################################################################################

package EMBL::DB;

require Exporter;
our @ISA = qw(Exporter);
# Automatically exported symbols
our @EXPORT    = qw(dbconnect dblink);
# Manually exported symbols
our @EXPORT_OK = qw();

use DBI;

# TODO use Config::IniFiles;

# TODO use Log::Log4perl qw(get_logger :levels);
# my $logger = get_logger(__PACKAGE__);
# $logger->level($DEBUG);

# Other modules in our hierarchy
use lib "..";


################################################################################
=head2 dbconnect

 Title   : dbconnect
 Usage   : dbconnect("dbhost.organisation.org", "your_database_name");
 Function: 
 Returns : Reference to a L<DBI> handle or B<undef>
 Args    : host String name of the database host
           db String name of the database to connect to
           reconnect Bybasses cached connection, returns a fresh connection

Assumes that no username or password are necessary.

Do not forget to do:

$dbh->close() on the handle when you are done using it.

Set $reconnect=1 when you need to be connected to more than one DB at a time.

=cut

sub dbconnect {
    my ($host, $db, $reconnect) = @_;

    # Use cached connection
    our $dbh;
    if ($dbh && ! $reconnect) { return $dbh; }

    #TODO use ini file for defaults
    $host ||= "pc-russell12";
    $db ||= "mpn_i2";

    $dbh = DBI->connect("dbi:mysql:dbname=${db};host=${host}");

    $dbh or 
        print STDERR "Cannot connect to DB '${db}' on host '${host}'\n";
    return $dbh;

} # dbconnect


################################################################################
=head2 dblink

 Title   : dblink
 Usage   : my $kegg_id = dblink($seq_obj, 'kegg');
 Function: Finds an xref idendifier within a L<Bio::Seq>
 Returns : Scalar string, e.g. "mpn:MPN567" or undef
 Args    : A L<Bio::Seq>, will often contain L<Bio::Annotation::DBLink> objects

Looks up, within a L<Bio::Seq> any database cross-references, given an
case-insentitive ID.

=cut

sub dblink {
    my ($seq, $db) = @_;
    # All Annotation objects tagged as a 'dblink' annotation
    my @values = $seq->annotation()->get_Annotations('dblink');
    foreach my $value ( @values ) {
        # value is an Bio::AnnotationI and a Bio::DB::DBLink
        # Find the xref of choice
        next unless lc($value->database()) eq lc($db);
        # Found our DB, grab the ID
        return $value->primary_id();
    }
}


###############################################################################

1;

__END__
