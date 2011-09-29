#!/usr/bin/env perl

=head1 NAME

SBG::Role::Writable - 

=head1 SYNOPSIS



=head1 DESCRIPTION


=head1 SEE ALSO

L<Moose::Role>

=cut

package SBG::Role::Writable;
use Moose::Role;

use Scalar::Util qw/blessed/;
use Module::Load qw/load/;

use SBG::IO;

=head2 write

 Function: Writes an object using a format plugin
 Example : $complex->write('pdb'); # Uses ComplexIO::pdb::write($complex);
 Returns : Path to file written too (which may be a temp file) 
 Args    : %ops are passed to L<SBG::IOI>, where output file can be given

Goes to Standard output by default.

=cut

sub write {
    my ($self, $format, %ops) = @_;

    my $io;
    if ($format) {
        my $class         = blessed $self;
        my $format_module = "${class}IO::${format}";
        eval { load $format_module; };
        if ($@) {
            warn "Could not load format: $format_module :\n$@\n";
            return;
        }
        $io = $format_module->new(%ops);
    }
    else {
        $io = SBG::IO->new(%ops);
    }
    $io->write($self);
    return $io->file;

}

no Moose::Role;
1;

