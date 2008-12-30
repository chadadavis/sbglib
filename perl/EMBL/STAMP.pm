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


# -min_fit 30
# -sc_cut 2.0
sub do_stamp {
    my $dom = shift;

    my $stamp = $config->val('stamp', 'executable') || 'stamp';
    my $min_fit = $config->val('stamp', 'min_fit') || 30;
    my $sc_cut = $config->val('stamp', 'sc_cut') || 2.0;
    my $min_sc_to_keep= $sc_cut;

    my $stamp_pars = " -n 2 -slide 5 -s -secscreen F -scancut ".$sc_cut." -opd ";


    my $in = new EMBL::DomainIO(-file=>$dom);
    my $out = new EMBL::DomainIO();
    my $dom_s;
    my %DOM;
    while (my $dom = $in->next_domain) {
        $DOM{$dom->stampid} = $out->write($dom);
        $dom_s .= $dom->stampid . ' ';
    }














    $tmp_probe = "tmp_".$$.".dom";
    $tmp_doms = "tmp_db_".$$.".dom";
    $tmp_prefix = "tmp_".$$;
    $tmp_scan = $tmp_prefix . ".scan";
    
    $n_disjoins=0;
    @DSET = keys %DOM;
    $ndom = @DSET;
    $probes_tried=0;
    %TRIED = ();
    %HAVE = ();
    $probe = $DSET[0];
    $missing = $ndom;
    $in_disjoint=0;
    if($ndom>=2) {
        while(($missing>0) && ($probes_tried<$ndom)) {
            if($probe eq "") { 
                # Get another probe from the set that are included
                foreach $dom (keys %HAVE) {
                    if(!defined($TRIED{$dom})) { $probe = $dom; }
                }
            }
            if($probe eq "") { # Get another probe from anywhere (i.e. unconnected now)
                foreach $dom (@DSET) {
                    if(!defined($TRIED{$dom})) { 
                        $probe = $dom; 
                        $in_disjoint=1;
                        printf("%%Warning potential disjoint \n");
                    }
                }
            }
            if($probe eq "") {
                printf("Out of probes and %d still missing\n",$missing);
            }
#  printf("STAMP_SET F %s P %s VS %d OF %d doms\n",$fold,$probe,$missing,$ndom);
            open(OUT,">$tmp_probe") || die "Error writing $tmp_probe\n";
            print OUT $DOM{$probe};
            close(OUT);
            open(OUT,">$tmp_doms") || die "Error writing $tmp_doms\n";
            foreach $dom (@DSET) {
                if((!defined($HAVE{$dom})) && ($dom ne $probe)) {
                    print OUT $DOM{$dom};
                    
                }
            }
            close(OUT);
            $com = $stamp . " " . $stamp_pars . " -l ".$tmp_probe." -prefix ".$tmp_prefix." -d ".$tmp_doms."|";
            open(IN,"$com") || die "Error running/reading $com\n";
            %KEEP = ();
            while(<IN>) {
                if((/^Scan/) && (!/skipped/) && (!/error/) && (!/missing/)) {
                    chomp;
                    print "%",$_;
                    #Scan 1ddiA.c.25.1.4-1 1qfjB.c.25.1.1-1    1   5.772   1.816  153  135  162  102  102    9  19.61  82.35 7.27e-43
                    @t = split(/\s+/);
                    $id1 = $t[1];
                    $id2 = $t[2];
                    $sc = $t[4];
                    $nfit = $t[9];
                    if(($sc > 0.5) && (($sc>=$min_sc_to_keep) || ($nfit >= $min_fit))) {
                        $HAVE{$id1}=1;
                        $HAVE{$id2}=1;
                        $KEEP{$id1}=1;
                        $KEEP{$id2}=1;
                        print " ** ";
                    }
                    print "\n";
                }
            }
            close(IN);
            $com = "sorttrans -f ".$tmp_scan." -s Sc 0.5 -i |";
            open(IN,"$com") || die "Error running/reading $com\n";
            $output=0;
            $trans_s = "";
            $good_trans=0; # Only good if something other than the probe is there
            $nd=0;
            while(<IN>) {
                if((!/\%/) && (!/\#/)) {
                    if(/\{/) {
#         printf("Changed %s\n",$_);
                        if($nd>0) {
                            s/_[0-9]+ {/ {/
                        }
                        $nd++;
#         printf("     to %s\n",$_);
                        $id = (split(/\s+/,$_))[1];
                        if(defined($KEEP{$id})) { 
                            if($id ne $probe) { $good_trans=1 }
                            $output=1;
                        } else { 
                            $output=0 
                        }
                    }
                    if($output==1) { 
                        $trans_s .= $_;
                    }
                }
            }
            
            close(IN);

            if($good_trans==1) {
                print "%TRANS_BEGIN\n";
                $trans_s_reordered = reorder($trans_s,$dom_s);
                print $trans_s_reordered;
                print "%TRANS_END\n";
                if($in_disjoint==1) {
                    $n_disjoins++;
                }
            }
            
            $TRIED{$probe}=1;
            $probes_tried++;
            $probe = "";
            $missing = $ndom;
            foreach $dom (keys %HAVE) { $missing-- }
        }
    }
    printf("%%Summary %4d out of %4d domains linked using %4d probes giving a total of %4d trans files (when linked)\n", 
           $ndom-$missing,$ndom,$probes_tried,$n_disjoins+1);

    unlink $tmp_probe;
    unlink $tmp_doms;
    unlink $tmp_scan;

} # do_stamp

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
            printf("Here assigned id %s from %s\n",$id,$T[$i]);

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
