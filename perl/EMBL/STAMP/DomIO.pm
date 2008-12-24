#!/usr/bin/env perl

# TODO POD

# TODO use Spiffy

package EMBL::STAMP::DomIO;

# TODO DEL
use lib "../..";

use Spiffy -Base, -XXX;
field 'fh';

# TODO rename to EMBL::STAMP::Dom;
use EMBL::CofM;


################################################################################

# TODO DOC
sub new() {
    my $self = {};
    bless $self, shift;
    my $fh = shift;
    $self->{fh} = $fh;
    return $self;
}


# a EMBL::CofM and an open file handle
sub write {
    my ($dom) = @_;
    my $fh = $self->fh;
    print $fh $dom, "\n";
}


sub next_dom {
    my $fh = $self->fh;
    while (<$fh>) {
        # Comments
        next if /^\s+\%/;
        # Create/parse new domain header
        unless (/^(\S+) (\S+) \{ ([^\}]+)/) {
            print STDERR "Cannot parse: $_";
            return undef;
        }

        my $dom = new EMBL::CofM();
        $dom->file($1);
        $dom->label($2);
        $dom->description($3);
        
        # Header ends, i.e. contains no transformation
        if (/\}\s*$/) { 
            return $dom;
        }

        # Parse transformtion
        my $transstr = $self->transstr;
        my $trans = new EMBL::Transformation();
        $trans->loadstr($transstr);
        $dom->cumulative($trans);
        return $dom;
    }
    # End of file
    return undef;
} # next_dom

sub transstr {
    my $transstr = shift;
    my $fh = $self->fh;
    while (<$fh>) {
        chomp;
        # Skip comments
        next if /^\s+\%/;
        $transstr .= $_;
        # Stop after a } has been encountered, and remove it
        last if $transstr =~ s/}//g;
    }
    return $transstr;
}


