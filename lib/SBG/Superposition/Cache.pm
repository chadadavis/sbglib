#!/usr/bin/env perl

=head1 NAME

SBG::Superposition::Cache -

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::STAMP> , L<SBG::DB::trans> , <SBG::U::RMSD>

=cut

package SBG::Superposition::Cache;
use strict;
use warnings;
use base qw/Exporter/;

our @EXPORT_OK = qw/superposition/;

use Log::Any qw/$log/;

use SBG::Cache qw/cache/;
use SBG::STAMP;
use SBG::DB::trans;


sub superposition_native {
    my ($fromdom, $ontodom, $ops) = @_;

    my $fromfile = $fromdom->file;
    my $ontofile = $ontodom->file;
    if (   $fromfile eq $ontofile
        && $fromdom->descriptor eq $ontodom->descriptor)
    {
        $log->debug("Identity: $fromdom");
        return SBG::Superposition->identity($fromdom);
    }

    my $superpos;

    # Try cache
    my $cachekey = "${fromdom}=>${ontodom}";
    my $cache = cache();
    unless (defined $superpos) {
        $superpos = $cache->get($cachekey);

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

    my $invkey = "${ontodom}=>${fromdom}";
    if (defined $superpos) {
        $cache->set($cachekey, $superpos);

        # Also save the inverse, since we already know it implicitly
        $cache->set($invkey, $superpos->inverse);
        return $superpos;
    }
    else {

        # Negative caching
        $cache->set($cachekey, []);
        $cache->set($invkey,   []);
        return;
    }

}    # superposition_native

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
    $log->debug("$fromdom=>$ontodom");

    my $superpos = superposition_native($fromdom, $ontodom);
    return unless defined $superpos;

    # If neither Domain has been transformed from native orientation, we're done
    return $superpos
        unless ($fromdom->transformation->has_matrix
        || $ontodom->transformation->has_matrix);

    # Right-to-left application of transformations to get fromdom=>ontodom
    # First, inverse $fromdom back to it's native transform
    # Then, apply the transform between the native domains
    # Last, apply the transform stored in $ontodom, if any
    my $prod = $ontodom->transformation x $superpos->transformation
        x $fromdom->transformation->inverse;

    $superpos->transformation($prod);
    return $superpos;

}    # superposition

1;

