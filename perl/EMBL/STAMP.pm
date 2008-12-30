#!/usr/bin/env perl

=head1 NAME

EMBL::CofM - Computes STAMP centre-of-mass of an EMBL::Domain

=head1 SYNOPSIS

 use EMBL::CofM;

=head1 DESCRIPTION

Looks up cached results in database, if available. This is only the case for
full chains. Otherwise, cofm is executed anew.

Also fetches radius of gyration of the centre of mass.

=head1 SEE ALSO

L<EMBL::Domain>

=cut

################################################################################

package EMBL::STAMP;
use EMBL::Root -base, -XXX;

our @EXPORT = qw(do_stamp stampfile string2doms doms2string reorder2 reorder);

use warnings;
use Carp;
use File::Temp qw(tempfile);
use IO::String;

use EMBL::Transform;
use EMBL::Domain;
use EMBL::DomainIO;

################################################################################


sub transform {
    my ($transfile) = @_;

    system("transform -f $transfile -g -o out.pdb") == 0 or
        die("$!");
    rename "out.pdb", "in.pdb";

}


# returns EMBL::Transform
# Transformation will be relative to fram of reference of destdom
sub stampfile {
    my ($srcdom, $destdom) = @_;

    # STAMP uses lowercase chain IDs
    $srcdom = lc $srcdom;
    $destdom = lc $destdom;

    if ($srcdom eq $destdom) {
        # Return identity
        return new EMBL::Transform;
    }

    print STDERR "\tSTAMP ${srcdom}->${destdom}\n";
    my $dir = "/tmp/stampcache";
    `mkdir /tmp/stampcache` unless -d $dir;
#     my $file = "$dir/$srcdom-$destdom-FoR.csv";
    my $file = "$dir/$srcdom-$destdom-FoR-s.csv";

    if (-r $file) {
        print STDERR "\t\tCached: ";
        if (-s $file) {
            print STDERR "positive\n";
        } else {
            print STDERR "negative\n";
            return undef;
        }
    } else {
        my $cmd = "./transform.sh $srcdom $destdom $dir";
        $file = `$cmd`;
    }

    my $trans = new EMBL::Transform();
    unless ($trans->loadfile($file)) {
        print STDERR "\tSTAMP failed: ${srcdom}->${destdom}\n";
        return undef;
    }
    return $trans;
} 


# TODO DEL
# This is already in DomainIO
sub parsetrans {
    my ($transfile) = @_;
    open(my $fh, $transfile);
    my %all;
    $all{'copy'} = [];
    my @existing;
    while (<$fh>) {
        next if /^%/;
        if (/^(\S+) (\S+) \{ ([^\}]+)/) {
            $all{'file'} = $1;
            $all{'name'} = $2;
            $all{'dom'} = $3;
            # The last line here includes a trailing }
            $all{'transform'} = [ <>, <>, <> ];
        } elsif (/^(\S+) (\S+) \{ (.*?) \}/) {
            push @{$all{'copy'}}, $_;
        } else {
            print STDERR "?: $_";
        }
    }
    close $fh;
    return %all;
}


################################################################################



# Turns a string into array of EMBL::Domain, returns array ref
sub string2doms {
    my $str = shift;
    my $iostr = new IO::String($str);
    my $iodom = new EMBL::DomainIO(-fh=>$iostr);
    my @doms;
    while (my $dom = $iodom->next_domain) {
        push @doms, $dom;
    }
    return \@doms;
}

# TODO get this working on arbitrary fields, other than stampid
sub reorder2 {
    my ($ordering, $objects, $func) = @_;
    # First put the objects into a dictionary, indexed by $func
#     my %dict = map { $_->$func() => $_ } @$objects;
    my %dict = map { $_->stampid() => $_ } @$objects;
    # Sorted array based on given ordering of keys
    my @sorted = map { $dict{$_} } @$ordering;
    return \@sorted;
}

# Turns a array of EMBL::Domain's into string
sub doms2string {
    my ($doms) = @_;
    my $outstr;
    my $out = new EMBL::DomainIO(-fh=>new IO::String($outstr));
    $out->write($_, -newline=>1) for @$doms;
    return $outstr;
}

# dom_s is space-separated list of identifiers/labels
#  This defines the desired output order

# trans_s is line-separated. Series of domains (+transformations, it seems)
#   These are read in, parsed, indexed by stampid, then sorted back to a string
sub reorder {
    my($trans_s, $dom_s) = @_;

    my($trans_s_reordered) = "";
    my(@T) = split(/\n/,$trans_s);
    my(@D) = split(/\s+/,$dom_s);
    my(%TR) = ();
    my($id) = "";
    my($old_count)=0;
    my($new_count)=0;
    for(my $i=0; $i<@T; ++$i) {
        # A header line
        if(($T[$i] !~ /^%/) && ($T[$i] =~ /{/)) { # end }
            # The stampid
            $id = (split(/\s+/,$T[$i]))[1];
#             printf("Here assigned id %s from %s\n",$id,$T[$i]);

            # Index header lines by stampid
            $TR{$id} = $T[$i]."\n";
            $old_count++;
        } elsif(($T[$i] !~ /^%/) && ($id ne "")) {
            $TR{$id} .= $T[$i]."\n";
        }
    }

    for(my $i=0; $i<@D; ++$i) {
        if(defined($TR{$D[$i]})) {
            $new_count++;
            $trans_s_reordered .= $TR{$D[$i]};
        }
    }
    if($old_count != $new_count) {
        $trans_s_reordered .= sprintf("%% WARNING: old and new count different (%d %d)\n",$old_count,$new_count);
    }
    return $trans_s_reordered;
} # reorder


################################################################################
1;
