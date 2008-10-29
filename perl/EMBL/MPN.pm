#!/usr/bin/env perl

=head1 NAME

EMBL::MPN - Utilities for working with Mycoplasma pneumoniae data

=head1 SYNOPSIS

use EMBL::MPN;



=head1 DESCRIPTION


=head1 BUGS

None known.

=head1 REVISION

$Id: Prediction.pm,v 1.33 2005/02/28 01:34:35 uid1343 Exp $

=head1 APPENDIX

Details on functions implemented here are described below.
Private internal functions are generally preceded with an _

=cut

################################################################################

package EMBL::MPN;

require Exporter;
our @ISA = qw(Exporter);
# Automatically exported symbols
our @EXPORT    = qw(kegg_seq);
# Manually exported symbols
our @EXPORT_OK = qw();


# TODO use Log::Log4perl qw(get_logger :levels);
# my $logger = get_logger(__PACKAGE__);
# $logger->level($DEBUG);

# Other modules in our hierarchy
use lib "..";
use EMBL::DB;




###############################################################################

1;

__END__
