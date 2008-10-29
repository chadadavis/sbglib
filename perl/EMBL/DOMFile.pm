#!/usr/bin/env perl

package EMBL::DOMFile;

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


sub _read {
    my ($self, $file) = @_;
    open my($fh), $file;
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
            if ($dom->{'descriptor'} =~ /CHAIN (\S)/) {
                $dom->{'chain'} = $1;
            }
            
            # Includes a transformation?
            if (/\}$/) {
                # NB: The last line here includes a trailing }
                $dom->{'transform'} = [ <>, <>, <> ];
            }
            $self->add_domain($dom);
        } else {
            print STDERR "Cannot parse: $_";
        }
    }
    close $fh;
    return $self;
}

sub add_domain {
    my ($self, $dom) = @_;
    push @{$self->{'domains'}}, $dom;
    return $self;
}

################################################################################


package EMBL::Dom;

use overload ('""' => '_tostring');

sub new {
    my ($class, @args) = @_;
    my $self = {};
    bless $self;
    return $self;
}

sub _read {
    my ($self, $fh) = @_;
 
    while (<$fh>) {
        # Comments
        next if /^%/;
        if (/^(\S+) (\S+) \{ ([^\}]+)/) {
            $self->{'file'} = $1;
            $self->{'id'} = $2;
            $self->{'descriptor'} = $3;
            # Try to also parse out single chain
            $self->{'chain'} = _parse_chain($self->{'descriptor'});
            
            # Includes a transformation? (i.e. the line isn't closed with }
            # TODO DES separate sub
            unless (/\}\s*$/) {
                # NB: The last line here includes a trailing }
                # TODO BUG This assumes no comments in the transformation block
                $self->{'transformation'} = [ <>, <>, <> ];
            }
            last;
        }
    }
}

sub _parse_chain {
    my ($descriptor) = @_;
    if ($descriptor =~ /CHAIN (\S)/) {
        return $1;
    } else {
        return undef;
    }
}
