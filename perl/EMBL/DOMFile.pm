#!/usr/bin/env perl

package EMBL::DomIO;

use overload ('""' => '_tostring');

# TODO POD



################################################################################

# TODO DOC
sub new {
    my ($class, @args) = @_;
    my $self = {};
    bless $self;
    
    # Each domain entry in a file stored here
    $self->{domains} = [];
    return $self;
}


# TODO DOC
# Stringify
# Don't need to call this directly
sub tostring {
    my ($self) = @_;
    return "";
}

# TODO needs to read multiple Segments
# Need a STAMP::DomIO->next_dom interface

sub next_dom {
    my ($self, $fh) = @_;
    while (<$fh>) {
        # Comments
        next if /^%/;
        # Create/parse new domain
        my $dom = {};
        if (/^(\S+) (\S+) \{ ([^\}]+)/) {
            $dom->{'file'} = $1;
            $dom->{'id'} = $2;
            $dom->{'descriptor'} = $3;
            # Try to also parse out single chain
            $self->{'chain'} = _parse_chain($self->{'descriptor'});

            # Includes a transformation?
            # TODO DES separate sub
            unless (/\}\s*$/) {
                # NB: The last line here includes a trailing }
                # TODO BUG This assumes no comments in the transformation block
                $self->{'transformation'} = [ <>, <>, <> ];
            }
            $self->add_domain($dom);
        } else {
#             print STDERR "Cannot parse: $_";
            print STDERR "Cannot parse: $_";
        }
    }
    # End of file
    return undef;
} # next_dom

sub _parse_chain {
    my ($descriptor) = @_;
    if ($descriptor =~ /CHAIN (\S)/) {
        return $1;
    } else {
        return undef;
    }
}


sub add_domain {
    my ($self, $dom) = @_;
    push @{$self->{'domains'}}, $dom;
    return $self;
}


