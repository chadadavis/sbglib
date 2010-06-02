#!/usr/bin/env perl

=head1 NAME

SBG::U::HTML - Utilities

=head1 SYNOPSIS

 use SBG::U::HTML qw/formattd .../;


=head1 DESCRIPTION

=head1 SEE ALSO


=cut

package SBG::U::HTML;

use CGI qw/:standard *table/;

use SBG::U::List qw/maprange/;

use SBG::Run::pdbc qw/pdbc/;

use base qw(Exporter);

our @EXPORT_OK = qw/
formattd
rcsb
/;



sub formattd {
    my ($val, $format, $range) = @_;
    $val = sprintf($format, $val) if $format;
    if (ref $range) {
        my $color = mapcolor($val, @$range);
        return td({-bgcolor=>$color}, $val);
    } else {
        return td($val);
    }
}


sub rcsb {
    my ($str) = @_;
    my ($pdb, $chain) = $str =~ /(\d\w{3})(\w?)/;
    # If there is a chain, get its chain description, otherwise entry header
    my $pdbc = pdbc($pdb);
    my $title;
    $title = $pdbc->{chain}{$chain} if $chain;
    $title ||= $pdbc->{'header'};

    my $base = 'http://www.rcsb.org/pdb/explore.do?structureId=';
    my $url = $base . $pdb;
    my $a = a({-title=>$title,-target=>'_blank',-href=>$url}, $pdb.$chain);
    # Return the prematch, if any, the new link, and the postmatch
    return $` . $a . $'; # emacs parser wants an extra '

}


sub mapcolor {
    my ($val, $min, $max, $colora, $colorb) = @_;
    $colora ||= 0x33;
    $colorb ||= 0xff;
    my $mapped = maprange($val, $min, $max, $colora, $colorb);
    my $hex = sprintf("%x", $mapped);
    my $hexstr = '#' . ($hex x 3);
    return $hexstr;
}




1;
__END__


