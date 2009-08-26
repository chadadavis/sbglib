#!/usr/bin/env perl

=head1 NAME



=head1 SYNOPSIS



=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::STAMP> , L<Cache::File>

=cut

################################################################################

package SBG::STAMP::Cache::File;
use base qw/Exporter/;

our @EXPORT_OK = qw(do_stamp sorttrans stamp pickframe superpose pdbc);

use strict;
use warnings;


# TODO use Cache::FileCache

# Lazy initialisation of directories later ...
our $tmpdir;
our $cachedir;


################################################################################
=head2 superpose

 Function: Provides L<SBG::Transform> required to put $fromdom onto $ontodom
 Example :
 Returns : L<SBG::Transform>
 Args    : 
           fromdom
           ontodom

Does not modify/transform $fromdom.

If a L<SBG::Domain> already has a non-identity L<SBG::Transform>, it is not
considered here. I.e. the transformation will be the one that places the native
orientation of $fromdom onto the native orientation of $ontodom.

You will still need to then transform $fromdom.

=cut
sub superpose {
    my ($fromdom, $ontodom, %ops) = @_;
    $ops{'cache'} = 1 unless defined $ops{'cache'};
    $logger->trace("$fromdom onto $ontodom");

    if ($fromdom eq $ontodom) {
        $logger->trace("Identity");
#         return new SBG::Transform();
        return SBG::Transform::id();
    }

    # Check database cache
    # Useless, if we need Sc and seqID and all those meta-data
    my $trydb = superpose_query($fromdom, $ontodom);
    return $trydb if $trydb;

    # Check local disk cache
    my $cached = cacheget($fromdom, $ontodom) if $ops{'cache'};
    if (defined $cached) {
        if ($cached) {
            # Positive cache hit
            return $cached;
        } else {
            # Negative cache hit
            return;
        }
    }

    # Otherwise, try locally
    return superpose_local($fromdom, $ontodom, %ops);

} # superpose


################################################################################
=head2 superpose_local

 Function: run stamp locally, to do superposition of one domain onto another
 Example :
 Returns : L<SBG::Transform>
 Args    :


=cut
sub superpose_local {
    my ($fromdom, $ontodom, %ops) = @_;
    $ops{'cache'} = 1 unless defined $ops{'cache'};
    $logger->trace("$fromdom onto $ontodom");

    my ($doms, $fields) = do_stamp($fromdom, $ontodom);
    unless (@$doms) {
        # Cannot be STAMP'd. Add to negative cache
        cacheneg($fromdom,$ontodom);
        return;
    }

    # Reorder @doms based on the order of $fromdom, $ontodom
    my $ordered = reorder($doms, 
                          [ $fromdom->id, $ontodom->id],
                          sub { $_->id });
    
    # Want transformation relative to $ontodom
    # I.e. applying the resulting transformation to $fromdom results in $ontodom
    # The *absolute* transformation, that puts [0] into frame-of-ref of [1]
    my ($from, $to) = @$ordered;
    my $trans = $from->transformation->relativeto($to->transformation);


    # Store the meta data directly in this object
    # TODO DES bad style doing this here
    $trans->{$_} = $fields->{$_} for keys %$fields;

    # Set from's transformation to be the one that's relative to to's
    $from->transformation($trans);
    # Reset to's transform (to the identity)
    $to->transformation(new SBG::Transform);
    $logger->debug("Transformation: ", $fromdom->id, ' ', $ontodom->id, "\n$trans");    

    # Positive cache
    cachepos($from, $to) if $ops{'cache'};
    return $trans;

} # superpose_local



sub _cache_file {
    my ($fromdom, $ontodom) = @_;
    _init_cache();
    my $file = $cachedir . '/' . $fromdom->id . '-' . $ontodom->id . '.ntrans';
    $logger->trace("Cache: $file");
    return $file;
}

sub cacheneg {
    my ($fromdom, $ontodom) = @_;
    $logger->trace();
    my $file = _cache_file($fromdom, $ontodom);
    my $fh;
    open $fh, ">$file";
    # But write nothing ...
}

# Trans is the Transformation object to be contained in the From domain that
# would superpose it onto the Onto domain.
sub cachepos {
    my ($fromdom, $ontodom) = @_;
    $logger->trace();
    my $file = _cache_file($fromdom, $ontodom);
    my $io = new SBG::IO(file=>">$file");
    # STAMP scores, etc.

    $io->write($fromdom->transformation->headers);
    # Write onto domain (has no transform, it's the reference);
    $io->write($ontodom->asstamp);
    # Write from domain (has the transform)
    $io->write($fromdom->asstamp);
    # Succesful if the file exists and is not empty
    return -s $file;
}

# Returns:
# miss: undef
# neg hit: 0
# pos hit: Domain with Transform
sub cacheget {
    my ($fromdom, $ontodom) = @_;
    $logger->trace("$fromdom onto $ontodom");
    my $file = _cache_file($fromdom, $ontodom);
    my $io;
    if (-r $file) {
        # Cache hit
        if (-s $file) {
            $logger->debug("Positive cache hit");
            return new SBG::Transform(file=>$file);
        } else {
            $logger->debug("Negative cache hit");
            return 0;
        }
    } else {
        $logger->debug("Cache miss");
        return;
    }
} # cacheget


# tempfile unlinked when object leaves scope (garbage collected)
sub _tmp_prefix {
    _init_tmp();
    my $tmp = new File::Temp(TEMPLATE=>"scan_XXXXX", DIR=>$tmpdir);
    return $tmp;
}


sub _init_tmp {
    our $tmpdir;
    $tmpdir ||= config()->val(qw/tmp tmpdir/) || $ENV{TMPDIR} || '/tmp';
    mkdir $tmpdir unless -d $tmpdir;
}


sub _init_cache {
    our $cachedir;
    $cachedir ||= config()->val(qw/stamp cache/) || "$tmpdir/stampcache";
    mkdir $cachedir unless -d $cachedir;
}


################################################################################
1;




