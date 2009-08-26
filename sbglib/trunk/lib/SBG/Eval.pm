#!/usr/bin/env perl

=head1 NAME

SBG::Eval - Evaluation routine to test accuracy of assembly of test complexes

=head1 SYNOPSIS

 use SBG::Eval;

=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::NetworkIO> , L<SBG::ComplexIO>

=cut

################################################################################

package SBG::Eval;
use Moose;

with 'SBG::Role::Storable';
with 'SBG::Role::Clonable';

use Moose::Autobox;
use autobox ARRAY => 'SBG::U::List';
use SBG::U::List qw/mean sum median/;


my @extrinsic = qw/target tsize model msize cover rmsd olap irmsd/;
my @intrinsic = qw/pval seqid eval sc glob/;
my @fields = (@extrinsic, @intrinsic);

has \@fields => (
    is => 'rw',
    );

has 'tobject' => (
    is => 'rw',
    isa => 'SBG::Complex',
    );

has 'mobject' => (
    is => 'rw',
    isa => 'SBG::Complex',
    );

has 'avgmat' => (
    is => 'rw',
    );


has 'target' => (
    is => 'rw',
    isa => 'SBG::Eval::Field',
    default => sub {
        new SBG::Eval::Field(
            label=>'target',flabel='%10s',fvalue=>'%10s') }
    );


has 'tsize' => (
    is => 'rw',
    isa => 'SBG::Eval::Field',
    default => sub {
        new SBG::Eval::Field(
            label=>'tsize',flabel='%5s',fvalue=>'%5d') }
    );


has 'model' => (
    is => 'rw',
    isa => 'SBG::Eval::Field',
    default => sub {
        new SBG::Eval::Field(
            label=>'model',flabel='%5s',fvalue=>'%5s') }
    );


has 'msize' => (
    is => 'rw',
    isa => 'SBG::Eval::Field',
    default => sub {
        new SBG::Eval::Field(
            label=>'msize',flabel='%5s',fvalue=>'%5d') }
    );


has 'cover' => (
    is => 'rw',
    isa => 'SBG::Eval::Field',
    default => sub { 
        new SBG::Eval:Field(
            range=>[0,100],label=>'cover',flabel=>'%5s%%', fvalue=>'%6.f') }
    );


has 'rmsd' => (
    is => 'rw',
    isa => 'SBG::Eval::Field',
    default => sub { 
        new SBG::Eval:Field(
            range=>[50,0],label=>'RMSD',flabel=>'%4s',fvalue=>'%4.1f') }
    );


has 'overlap' => (
    is => 'rw',
    isa => 'SBG::Eval::Field',
    default => sub { 
        new SBG::Eval:Field(
            range=>[0,100],label=>'overlap',flabel=>'%7s%%',fvalue=>'%8.f') }
    );


has 'irmsd' => (
    is => 'rw',
    isa => 'SBG::Eval::Field',
    default => sub { 
        new SBG::Eval:Field(
            range=>[20,0],label=>'iRMSD',flabel=>'%5s',fvalue=>'%5.2f') }
    );


has 'pval' => (
    is => 'rw',
    isa => 'SBG::Eval::Field',
    default => sub { 
        new SBG::Eval:Field(
            range=>[5,0],label=>'pVal',flabel=>'%9s',fvalue=>'%9g') }
    );


has 'zscore' => (
    is => 'rw',
    isa => 'SBG::Eval::Field',
    default => sub { 
        new SBG::Eval:Field(
            range=>[-5,5],label=>'Zscore',flabel=>'%6s',fvalue=>'%6.f') }
    );


has 'seqid' => (
    is => 'rw',
    isa => 'SBG::Eval::Field',
    default => sub { 
        new SBG::Eval:Field(
            range=>[0,100],label=>'SeqID',flabel=>'%5s%%',fvalue=>'%6.f') }
    );


has 'eval' => (
    is => 'rw',
    isa => 'SBG::Eval::Field',
    default => sub { 
        new SBG::Eval:Field(
            range=>[1e-20,1e-100],label=>'EVal',flabel=>'%12s',fvalue=>'%12g') }
    );


has 'sc' => (
    is => 'rw',
    isa => 'SBG::Eval::Field',
    default => sub { 
        new SBG::Eval:Field(
            range=>[0,10],label=>'Sc',flabel=>'%6s',fvalue=>'%6.3f') }
    );


has 'glob' => (
    is => 'rw',
    isa => 'SBG::Eval::Field',
    default => sub { 
        new SBG::Eval:Field(
            range=>[0,100],label=>'glob',flabel=>'%5s%%',fvalue=>'%6.f') }
    );



sub BUILD {
    my ($self) = @_;


}



################################################################################
__PACKAGE__->meta->make_immutable;
no Moose;
1;



