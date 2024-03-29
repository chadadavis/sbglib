#
#
# BioPerl module for REST access to RCSB metadata
#
# You may distribute this module under the same terms as perl itself

=head1 NAME

Bio::DB::RCSB - Database object interface to RCSB Protein Databank metadata

=head1 SYNOPSIS

 use Bio::DB::RCSB;
 my $dbh = Bio::DB::RCSB->new();
 # Optionally set a proxy (not necessary if already in your environment)
 $dbh->proxy([qw(http ftp)], 'http://russelllab.org:3128');
 my $xml = $dbh->describeMol(structureId=>'4hhb.A');
 # Parse the XML however you like (regex, XML::XPath, etc)

=head1 DESCRIPTION

For a description of all the functions available and their options, see:

 http://www.rcsb.org/pdb/software/rest.do
 
This module only supports a subset of those however. See the source for details.

=head1 AUTHOR - Chad A Davis

Email Chad A Davis E<lt>chad.a.davis@gmail.com E<gt>

=head1 SEE ALSO

=over 4

=item * L<WWW::PDB>

Allows for arbitrarily complex XML queries to RCSB web service.

=back

=cut

package Bio::DB::RCSB;
use strict;
use warnings;
our $VERSION = 20110929;
use 5.008;

use Moose;

# NB necessary to have Moose::Object first here, before other parents
extends qw/Moose::Object Bio::Root::Root/;


use LWP::UserAgent;

#use XML::XPath;
use Moose::Autobox;
use Log::Any qw/$log/;
use IO::String;

# Base URI for REST access
has '_rest' => (
    is      => 'rw',
    isa     => 'Str',                             # URI
    default => 'http://www.rcsb.org/pdb/rest/',
);

has '_cache' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} },
);

has '_ua' => (
    is         => 'rw',
    isa        => 'LWP::UserAgent',
    lazy_build => 1,
    handles    => [ qw(proxy) ],
);

sub _build__ua {
    my ($self) = @_;
    my $ua = LWP::UserAgent->new;
    # Load any proxy setting defined in the environment
    $ua->env_proxy;
    return $ua;
}

sub _fetch {
    my ($self, $uri) = @_;
    my $cache = $self->_cache;
    my $res   = $cache->at($uri);
    unless (defined $res) {
        $log->debug($uri);
        my $req = HTTP::Request->new(GET => $uri);
        my $res = $self->_ua->request($req);
        if ($res->is_success) {
            $cache->put($uri, $res->content);
        }
        else {
            $cache->put($uri, []);
        }
    }
    return if ref($cache->at($uri)) eq 'ARRAY';
    return $cache->at($uri);
}

# Base URI for linking to a structure page
has '_uri' => (
    is      => 'rw',
    isa     => 'Str',                                               # URI
    default => 'http://www.rcsb.org/pdb/explore.do?structureId=',
);

sub link_for {
    my ($self, $id) = @_;
    return $self->_uri . $id;
}

# TODO BUG: cannot get the organism for a single chain explicitly
sub organism {
    my ($self, %ops) = @_;
    my $xml = $self->describeMol(%ops);

    #    my $organismtext = _xml_xpath($xml);
    my $organismtext = _xml_regex($xml) or die "\n$xml\n";

    # May be multiple comma-separated organisms
    my @organisms = split /, /, $organismtext;
    my $counts = {};
    $counts->{$_}++ for @organisms;

    # Sort the hash by value (descending) to find the most frequent organism
    my @sorted =
        sort { $counts->{$b} <=> $counts->{$a} } $counts->keys->flatten;
    return $sorted[0];
}

sub _xml_regex {
    my $xml = shift;
    my ($organismtext) = $xml =~ m|Taxonomy name="(.*?)"|is;
    return $organismtext;
}

#sub _xml_xpath {
#    my $xml = shift;
#    my $xmlio = IO::String->new($xml);
#    my $xp = XML::XPath->new(ioref=>$xmlio);
#    my $query = '/PDBdescription/PDB/@organism';
#    my $organismtext = $xp->getNodeText($query);
#    return $organismtext;
#}

# Call any REST method
sub AUTOLOAD {
    my ($self, %ops) = @_;

    # Name of this function
    my ($verb) = our $AUTOLOAD =~ /::(\w+)$/;

    # Assembly URI based on verb and (sorted) options
    my $uri =
          $self->_rest 
        . $verb . '?'
        . join('&', map { $_ . '=' . $ops{$_} } sort keys %ops);
    $log->debug($uri);
    my $res = $self->_fetch($uri);
    return $res;
}

1;

__END__
