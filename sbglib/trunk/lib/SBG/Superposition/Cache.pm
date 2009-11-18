#!/usr/bin/env perl

=head1 NAME

SBG::Superposition::Cache -

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::STAMP> , L<SBG::DB::trans> , <SBG::U::RMSD>

=cut

################################################################################

package SBG::Superposition::Cache;
use strict;
use warnings;
use base qw/Exporter/;

our @EXPORT_OK = qw/superposition/;

# use Moose::Autobox;

use SBG::U::Log qw/log/;
use SBG::U::Cache qw/cache/;

use SBG::STAMP;
use SBG::DB::trans;



sub superposition_native {
    my ($fromdom, $ontodom, $ops) = @_;

    if ($fromdom->pdbid eq $ontodom->pdbid &&
        $fromdom->descriptor eq $ontodom->descriptor) {
        log()->trace("Identity: $fromdom");
        return SBG::Superposition->identity($fromdom);
    }

    my $superpos;
    
    # Try cache
    unless (defined $superpos) {
        $superpos = _cache_get($fromdom, $ontodom);
        # Negative cache? (i.e. superpostion previously found to be impossible)
        return if ref($superpos) eq 'ARRAY';
        return $superpos if defined $superpos;
    }

    # Try DB
    unless (defined $superpos) {
        $superpos = SBG::DB::trans::superposition_native($fromdom, $ontodom);
        # But dont' return, wait to cache it
    }

    # Try STAMP
    unless (defined $superpos) {
        $superpos = SBG::STAMP::superposition_native($fromdom, $ontodom);
        # But dont' return, wait to cache it
    }


    if (defined $superpos) {
        _cache_set($fromdom, $ontodom, $superpos);
        _cache_set($ontodom, $fromdom, $superpos->inverse);
        return $superpos;
    } else {
        _cache_set($fromdom, $ontodom, []);
        _cache_set($ontodom, $fromdom, []);
        return;
    }

} # superposition_native


################################################################################
=head2 superposition

 Function: 
 Example : 
 Returns : 
 Args    : 

This will produce a superposition that considers any existing transformations in
the given domains.

=cut
sub superposition {
    my ($fromdom, $ontodom, $ops) = @_;
    log()->trace("$fromdom=>$ontodom");
    
    my $superpos = superposition_native($fromdom, $ontodom);
    return unless defined $superpos;

    # If neither Domain has been transformed from native orientation, we're done
    return $superpos unless ($fromdom->transformation->has_matrix || 
                             $ontodom->transformation->has_matrix);

    # Right-to-left application of transformations to get fromdom=>ontodom
    # First, inverse $fromdom back to it's native transform
    # Then, apply the transform between the native domains
    # Last, apply the transform stored in $ontodom, if any
    my $prod = 
        $ontodom->transformation x 
        $superpos->transformation x 
        $fromdom->transformation->inverse;

    $superpos->transformation($prod);
    return $superpos;

} # superposition


################################################################################
=head2 _cache_get

 Function: 
 Example : 
 Returns : Re-retrieved object from cache
 Args    : [] implies negative caching

Cache claims to even work between concurrent processes!

=cut
sub _cache_get {
    my ($from, $to) = @_;
    my ($cache,$lock) = SBG::U::Cache::cache('sbgsuperposition');
    my $key = "${from}=>${to}";

    if (my $data = $cache->get($key)) {

        if (ref($data) eq 'ARRAY') {
            log()->debug("Cache hit (negative) ", $key);
            return $data;
        } else {
            log()->debug("Cache hit (positive) ", $key);
            return $data;
        }
    } 
    log()->debug("Cache miss ", $key);
    return;

} # _cache_get


=head2 _cache_set

 Function: 
 Example : 
 Returns : Re-retrieved object from cache
 Args    : [] implies negative caching

Cache claims to even work between concurrent processes!

=cut
sub _cache_set {
    my ($from, $to, $data) = @_;
    my ($cache,$lock) = SBG::U::Cache::cache('sbgsuperposition');
    my $key = "${from}=>${to}";

    my $status;

    # (NB [] means negative cache)
    if (ref($data) eq 'ARRAY') {
        $status = 'negative';
    } else {
        $status = 'positive';
    }

    log()->debug("Cache write ($status) $key");
    log()->trace(ref($data), "\n", $data);
    
    $cache->set($key, $data);

    # Verification;
    return $cache->is_valid($key);

} # _cache_set


################################################################################
1;



