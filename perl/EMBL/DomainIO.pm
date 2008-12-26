#!/usr/bin/env perl

# TODO POD

# TODO use Spiffy

package EMBL::DomIO;

use Spiffy -Base, -XXX;
field 'fh';

use lib "..";
# TODO rename to EMBL::STAMP::Dom;
use EMBL::CofM;
use EMBL::Transform;

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
# TODO BUG need a separate handle, opened for output
sub write {
    my ($dom) = @_;
    my $fh = $self->fh;
#     print $fh $dom->dom(), "\n";
}

sub write_dom {

}


sub write_assembly {

}

sub next_assembly {
    my $dom;
    my $assem = new EMBL::Assembly();
    while ($dom = $self->next_dom) {
        # Add Dom to Assembly
    }
    
}

sub next_dom {
    my $fh = $self->fh;
    while (<$fh>) {
        chomp;
        # Comments and blank lines
        next if /^\s*\%/;
        next if /^\s*$/;

        # Create/parse new domain header
        unless (/^(\S+)\s+(\S+)\s+\{ ([^}]+)\s+/) {
            print STDERR "Cannot parse:$_:";
            return undef;
        }

        my $dom = new EMBL::CofM();
        $dom->file($1);
        $dom->id_from_file();
        $dom->label($2);
        $dom->description($3);

        # Header ends, i.e. contains no transformation
        if (/\}\s*$/) { 
            return $dom;
        }

        # Parse transformtion
        my $transstr = $self->transstr;
        my $trans = new EMBL::Transform();
        $trans->loadstr($transstr);
        $dom->reset($trans);
        return $dom;
    }
    # End of file
    return undef;
} # next_dom

sub transstr {
    my $transstr = shift;
    my $fh = $self->fh;
    while (<$fh>) {
        # No chomp, keep this as CSV formatted text
#         chomp;
        # Comments and blank lines
        next if /^\s*\%/;
        next if /^\s*$/;
        $transstr .= $_;
        # Stop after a } has been encountered, and remove it
        last if $transstr =~ s/}//g;
    }
    return $transstr;
}


################################################################################
1;
