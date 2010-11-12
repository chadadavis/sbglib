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

    my $xml = $dbh->describeMol(structureId=>'4hhb.A');
    

=head1 DESCRIPTION

For a description of all the functions available and their options, see:

 http://www.rcsb.org/pdb/software/rest.do
 
This module only supports a subset of those however. See the source for details.

=head1 AUTHOR - Chad A. Davis

Email Chad A. Davis E<lt>chad.a.davis@gmail.com E<gt>

=head1 APPENDIX

The rest of the documentation details each of the object
methods. Internal methods are usually preceded with a _

=cut

# Let the code begin...

package Bio::DB::RCSB;
use Moose;
# NB necessary to have Moose::Object first here, before other parents
extends qw/Moose::Object Bio::Root::Root/;

our $MODVERSION = '0.0.1';

use LWP::UserAgent;
use XML::XPath;
use Moose::Autobox;
use Log::Any qw/$log/;
use IO::String;


# Base URI for REST access
has '_rest' => (
    is => 'rw',
    isa => 'Str', # URI
    default => 'http://www.rcsb.org/pdb/rest/',  
);


has '_cache' => (
    is => 'rw',
    isa => 'HashRef',
    default => sub { {} },
    );


has '_ua' => (
    is => 'rw',
    isa => 'LWP::UserAgent',
    lazy_build => 1,
);

sub _build__ua {
	my ($self) = @_;
    my $ua = LWP::UserAgent->new;
    return $ua;
}


sub _fetch {
    my ($self, $uri) = @_;    
    my $cache = $self->_cache;
    my $res = $cache->at($uri);
    unless (defined $res) {
    	$log->debug($uri);
   	    my $req = HTTP::Request->new(GET => $uri);
        my $res = $self->_ua->request($req);
        if ($res->is_success) {
            $cache->put($uri, $res->content);
        } else {
            $cache->put($uri, []);
        }   
    }
    return if ref($cache->at($uri)) eq 'ARRAY';
    return $cache->at($uri);
}
    

# Base URI for linking to a structure page
has '_uri' => (
    is => 'rw',
    isa => 'Str', # URI
    default => 'http://www.rcsb.org/pdb/explore.do?structureId=',
    );
    
    
sub link_for {
	my ($self, $id) = @_;
    return $self->_uri . $id;
}


# TODO BUG: cannot get the organism for a single chain explicitly
sub organism {
    my ($self, %ops) = @_;
    my $xml = $self->describePDB(%ops);          
    my $xmlio = IO::String->new($xml);
    my $xp = XML::XPath->new(ioref=>$xmlio); 
    my $query = '/PDBdescription/PDB/@organism';    
    my $organismtext = $xp->getNodeText($query);
    # May be multiple comma-separated organisms
    my @organisms = split /, /, $organismtext;
    my $counts = {};
    $counts->{$_}++ for @organisms;
    # Sort the hash by value (descending) to find the most frequent organism
    my @sorted = sort { $counts->{$b} <=> $counts->{$a} } $counts->keys->flatten;
    return $sorted[0];
    
}


sub _method {
	# Who called us
    my $verb = (caller(1))[3];
    # Just get the bit after the last :: (if any)
    $verb =~ s/.*:://;
    return $verb;   
}


sub describePDB {
	my ($self, %ops) = @_;	
	# Name of this function
	my $verb = _method;
	# Assembly URI based on verb and (sorted) options
	my $uri = $self->_rest . $verb . '?' . 
	   join('&', map {$_ . '=' . $ops{$_} } sort keys %ops);
	my $res = $self->_fetch($uri);
	return $res;
}



1;

__END__
