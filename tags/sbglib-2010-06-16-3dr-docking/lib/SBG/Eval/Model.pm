#!/usr/bin/env perl

=head1 NAME


=head1 SYNOPSIS


=head1 DESCRIPTION


# Distinguish: complex, interaction, superposition, component model scores
# Also distinguish scalar vs array score (median/mean these)

# Complex scores: 
## clashes (ArrayRef) globularity (scalar)

# interactions: HashRef
## interface_conserved 
## avg_frac_identical avg_gaps avg_n_res avg_seqid 
## avg_length avg_evalue avg_frac_conserved

# superpositions: HashRef
## Sc len sec_id seq_id q_len n_equiv nfit n_sec d_len RMS 

# models: HashRef
## evalue frac_identical frac_conserved seqid gaps length n_res

# Evaluation scores, ie. only measureable given the true target complex:
## coverage rmsd 

=head1 SEE ALSO



=cut



package SBG::Eval::Model;
use Moose;
with 'SBG::Role::Writable';
with 'SBG::Role::Storable';
with 'SBG::Role::Clonable';
with 'SBG::Role::Scorable';

use SBG::Role::Scorable qw/group_scores/;

use Moose::Autobox;
use SBG::U::List qw/mean sum median/;
use SBG::Complex;


# The whole name, e.g. 3EXE-net-0001-model-2355
has 'label' => (
    is => 'rw',
    isa => 'Str',
    );

# Just the model identifier, e.g. 2355
has 'id' => (
    is => 'rw',
    isa => 'Str',
    );

has 'complex' => (
    is => 'rw',
    isa => 'SBG::Complex',
    handles => [
        qw/size count superpositions clashes models interactions/
    ],
    );

has 'target' => (
    is => 'rw',
    isa => 'SBG::Eval::Target',
    );


sub _build_scores {
    my ($self) = @_;

    # Extrinsic scores (given the true target complex for comparison)
    my ($matrix, $rmsd) = 
        $self->complex->rmsd($self->target->complex);
    my $cscores = {
        rmsd => [ $rmsd ],
        coverage => [ 1.0 * $self->size / $self->target->size ],
        globularity => [ $self->complex->globularity, ],
    };


    # TODO DES belongs in Complex
    # Put Clashes with the models they belong to
    foreach my $key ($self->clashes->keys->flatten) {
        my $model = $self->models->at($key);
        my $clash = $self->clashes->at($key);
        $model->scores->put('clash', $clash);
    }

    # Extract arrays of scores from the superpositions, interactions, models
    # And convert Array of Hashes into Hash of Arrays
    my $sscores = group_scores(
        $self->superpositions->values->map(sub{$_->scores}),
        );
    my $iscores = group_scores(
        $self->interactions->values->map(sub{$_->scores}),
        );
    my $mscores = group_scores(
        $self->models->values->map(sub{$_->scores}),
        );
    
    return $cscores->merge($sscores)->merge($iscores)->merge($mscores);

}



__PACKAGE__->meta->make_immutable;
no Moose;
1;


__END__

# Formats for CSV files:

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





__PACKAGE__->meta->make_immutable;
no Moose;
1;



