#!/usr/bin/env perl

# TODO POD

package EMBL::DomainIO;

use Spiffy -Base, -XXX;
field 'fh';

use base "Bio::Root::Root";

use File::Temp qw(tempfile);
use Carp;

use EMBL::Domain;
use EMBL::Transform;

################################################################################

# TODO DOC
sub new () {
    my $self = bless {}, shift;
    # Params
    my ($fh, $file) = 
        $self->_rearrange(
            [qw(FH FILE)], 
            @_);

    if ($file) {
        $self->_open($file) or return undef;
    } elsif ($fh) {
        $self->fh($fh);
    }
    return $self;
}

# File here also has the "<" or ">" part at the front
sub _open {
    my $file = shift;
    my $fh;
    unless (open($fh, $file)) {
        print STDERR "$!\n";
        return undef;
    }
    $self->fh($fh);
    return $self;
}

sub close {
    return close $self->fh;
}



################################################################################
=head2 write

 Title   : write
 Usage   :
 Function:
 Example :
 Returns : 
 Args    : EMBL::Domain

Print in STAMP format, along with any transform(s) that have been applied.

TODO doc explain order of mat. mult.

=cut
sub write {
    my ($dom) = @_;
    my $fh = $self->fh;
    my $str = 
        join(" ",
             $dom->file,
             $dom->stampid,
             '{',
             $dom->descriptor,
        );
    # Do not print transformation matrix, if it is still the identity
    if ($dom->{tainted}) {
        $str .= " \n" . $dom->transformation->print . "}";
    } else {
        $str .= " }";
    }
    print $fh $str;
    return $str;

} # write


sub next_domain {
    my $fh = $self->fh;
    while (<$fh>) {
        chomp;
        # Comments and blank lines
        next if /^\s*\%/;
        next if /^\s*$/;

        # Create/parse new domain header
        unless (/^(\S+)\s+(\S+)\s+\{ ([^}]+)\s+/) {
            carp "Cannot parse:$_:";
            return undef;
        }

        my $dom = new EMBL::Domain();
        $dom->file($1);
        $dom->id_from_file();
        $dom->stampid($2);
        $dom->descriptor($3);

        # Header ends, i.e. contains no transformation
        if (/\}\s*$/) { 
            return $dom;
        }

        # Parse transformtion
        my $transstr = $self->transstr;
        my $trans = new EMBL::Transform();
        $trans->loadstr($transstr);
        $dom->transformation($trans);
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

# TODO DOC
sub pdbc {
    my ($pdbidchid) = @_;
    
}


################################################################################
1;
