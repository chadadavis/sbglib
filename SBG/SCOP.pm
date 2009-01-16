#!/usr/bin/env perl

=head1 NAME

SBG::SCOP - Utilities for working with SCOP, a functional interface

=head1 SYNOPSIS

 use SBG::SCOP;

=head1 DESCRIPTION


Also fetches radius of gyration of the centre of mass.

=head1 SEE ALSO

L<SBG::DB>

=cut

################################################################################

package SBG::SCOP;
use SBG::Root -base;

our @EXPORT_OK = qw(pdb2scop same);

use warnings;

use SBG::DB;

################################################################################
=head2 pdb2scop

 Title   : pdb2scop
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut
sub pdb2scop {
    my (%o) = @_;
    SBG::Root::_undash %o;
    $o{pdb} or return;

    my $dbh = dbconnect(-db=>$db) or return undef;
    # Static handle, prepare it only once
    our $pdb2scop_sth;


} # pdb2scop




################################################################################
1;

__END__


