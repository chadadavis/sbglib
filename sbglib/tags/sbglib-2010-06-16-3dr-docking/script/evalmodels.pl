#!/usr/bin/env perl

use strict;
use warnings;

use Moose::Autobox;
use autobox::List::Util;
use List::MoreUtils;
use File::Basename;
use Log::Any qw/$log/;
use File::NFSLock;
use Fcntl qw/LOCK_EX LOCK_NB/;


# Local libraries
use FindBin qw/$Bin/;
use lib "$Bin/../lib/";

use SBG::U::Object qw/load_object/;
use SBG::U::Log;
use SBG::U::List qw/mean avg median sum min max flatten argmax argmin/;
use PBS::ARGV qw/qsub/;
use SBG::U::Run qw/frac_of getoptions start_lock end_lock/;
use SBG::Run::pdbc qw/pdbc/;
use SBG::DomainIO::stamp;
use SBG::DomainIO::pdb;


# the 'models' base directory
my %ops = getoptions('modelbase=s', 'redo=i', 'target=s');

# Column header labels
my $tkeys = [ qw/tid tdesc tndoms tseqlen tnias/ ];
my $allkeys = [ 
    @$tkeys,
    qw/mid/,
    qw/rmsd/,
    qw/score/,
    qw/mndoms mseqlen pdoms pseqlen mnias/,
#     qw/pias/,
    qw/nsources/,
    qw/ncycles/,
    qw/scmin scmax scmed/,
    qw/glob/,
    qw/idmin idmax idmed/,
    qw/ifacelenmin ifacelenmax ifacelenmed/,
    qw/ifaceconsmin ifaceconsmax ifaceconsmed/,
#     qw/sas/,
    qw/olmin olmax olmed/,
    ];
# Keys that should be round to 2 decimal places
my $floatkeys = 
    [ qw/rmsd score pdoms pseqlen glob idmin idmax idmed ifaceconsmin ifaceconsmax ifaceconsmed olmin olmax olmed/ ];

# Try to submit to PBS, for each argument in @ARGV
# Recreate command line options;
my @jobids = qsub(options=>\%ops);
print "Submitted:\n", join("\n", @jobids), "\n", if @jobids;

# @ARGV is empty if all jobs could be submitted

exit unless @ARGV;

my $headerpath = '00-header.csv';
unless (-s $headerpath) {
    open my $fh, '>', $headerpath;
    print $fh $allkeys->join("\t"), "\n";
}


foreach my $file (@ARGV) {
    if (defined($ops{'J'})) {
        # The file is actually the Jth line of the list of files
        $file = PBS::ARGV::linen($file, $ops{'J'});
    }

    # Where we are
    my $basename = basename($file,'.model');
    my $dirname = basename dirname $file;
    my $basepath = "${dirname}/${basename}";
    # Skip if already finished
    next if -e $basepath . '.done';

    # Create target-specific directory for its models
    my $tid = $dirname;
    mkdir $tid;

    # Lock this model from other processes/jobs
    my $lock = start_lock($basepath);
    next if ! $lock && ! $ops{'debug'};

    # Start logging
    SBG::U::Log::init($basepath, %ops);

    # Mark jobs that are tried, but not done, this file deleted when finished
    # A cheap way to track what crashes before finishing
    my $tryingfile = $basepath . '.trying';
    open my $tryingfh, ">$tryingfile";
    close $tryingfh;

    my $targetfile = $ops{'target'};
    $targetfile ||= dirname($file) . "/../../targets/${tid}.target";

    unless (-r $targetfile) {
            $log->info(
            "Cannot read: $targetfile. Specify via: -target <target>");
    }
    $log->debug("targetfile: $targetfile");

    do_target($tid, $targetfile, $file);
    end_lock($lock, 1);
    unlink $tryingfile;
}



sub do_target {
    my ($basename, $targetfile, $modelfile) = @_;

    my $target = load_object($targetfile);

    my $stats = $target->scores->at('benchstats') if $target->scores;
    unless (defined $stats) {

        $target->id($basename) unless defined $target->id;

        unless ($target->description) {
            my $pdbc = pdbc($target->id);
            $target->description($pdbc->{'header'});
        }
        
        unless (defined $target->{'tseqlen'}) {
            my $tseqlen = 
                $target->models->values->map(sub{$_->subject->seq->length})->sum;
            $target->{'tseqlen'} = $tseqlen;
            $log->debug("target sequence length: $target->{'tseqlen'}");
        }

        $stats = {
            'tid' => $target->id,
            'tdesc' => $target->description,
            'tndoms' => $target->size,
            'tseqlen' => $target->{'tseqlen'},
            # TODO
            'tnias' => 0,
        };
        $target->scores->put('benchstats', $stats);
        $target->store($targetfile);
    }

    if (-e $modelfile) {
        do_model($target, $modelfile, $stats);
    } else {
        # If no models were produced, just a print a truncated header
        open my $fh, ">${basename}/${basename}-00000.csv";        
        print $fh $stats->slice($tkeys)->join("\t"), "\n";
        close $fh;
     }

}



sub do_model {
    my ($target, $modelfile, $stats) = @_;
    $log->debug($modelfile);
    my $model = load_object($modelfile);

    if ($ops{'redo'}) {
        $model->scores->delete('benchstats'); 
        $model->scores->delete('benchrmsd');
        $model->scores->delete('benchmatrix');
        $model->store($modelfile);
        $log->info("model stats and RMSD wiped an re-saved");
    }
    $stats = model_stats($target, $model, $stats);

    my $basename = basename($modelfile,'.model');
    my $dirname = basename dirname $modelfile;
    my $basepath = "${dirname}/${basename}";
 
    open my $fh, ">${basepath}.csv";
    # Print the CSV line, using predefined key ordering
    my $fields = $stats->slice($allkeys)->map(sub{defined $_?$_:''});
    print $fh $fields->join("\t"), "\n";
    close $fh;
    
    modeloutputs($target,$model);

    # Save any changes
    $model->store($modelfile);
}


sub model_stats {
    my ($target, $model, $stats) = @_;

    my $benchstats = $model->scores->at('benchstats');

    if (!$ops{'debug'} && !$ops{'redo'} && defined $benchstats) {
        return $benchstats;
    } 
        

    $stats->{'mid'} = $model->id();

    # domain models within this complex model
    my $dommodels = $model->models->values;
    my $mndoms = $dommodels->length;
    my $tndoms = $target->size;
    $stats->{'mndoms'} = $mndoms;
    # Percentage of component coverage
    $stats->{'pdoms'} = 100.0 * $mndoms / $tndoms;

    # Alignments
    my $alns = $dommodels->map(sub{$_->aln()});
    my $ids = $alns->map(sub{$_->overall_percentage_identity('long')});
    $stats->{'idmin'} = $ids->min;
    $stats->{'idmax'} = $ids->max;
    $stats->{'idmed'} = median($ids);
        

    # Model: interactions
    my $mias = $model->interactions->values;
    # Model: number of interactions
    my $mnias = $mias->length;
    $stats->{'mnias'} = $mnias;

    # Fractional residue conservations of each interaction.
    # The value for each interaction is the average of its two interfaces
    my $cons = $mias->map(sub{$_->scores->at('avg_frac_conserved')});
    $stats->{'ifaceconsmin'} = $cons->min;
    $stats->{'ifaceconsmax'} = $cons->max;
    $stats->{'ifaceconsmed'} = median($cons);
    
    # Number of residues in contact in an interaction, averaged between 2
    # interfaces.
    my $nres = $mias->map(sub{$_->scores->at('avg_n_res')});
    $stats->{'ifacelenmin'} = $nres->min;
    $stats->{'ifacelenmax'} = $nres->max;
    $stats->{'ifacelenmed'} = median($nres);


    # Number of template PDB structures used in entire model
    # TODO belongs in SBG::Complex
    my $idomains = $mias->map(sub{$_->domains->flatten});
    my $ipdbs = $idomains->map(sub{$_->pdbid});
    my $nsources = scalar List::MoreUtils::uniq $ipdbs->flatten;
    $stats->{'nsources'} = $nsources;

    # This is the sequence from the structural template used
    my $mseqlen = $dommodels->map(sub{$_->subject->seq->length})->sum;
    $stats->{'mseqlen'} = $mseqlen;
    # Percentage sequence coverage by the complex model
    my $pseqlen = 100.0 * $mseqlen / $stats->{'tseqlen'};
    $stats->{'pseqlen'} = $pseqlen;


    # Sequence coverage per domain
    my $pdomcovers = $dommodels->map(sub{$_->coverage()});
    $stats->{'seqcovermin'} = $pdomcovers->min;
    $stats->{'seqcovermax'} = $pdomcovers->max;
    $stats->{'seqcovermed'} = median($pdomcovers);


    # Edge weight, generally the seqid
    my $weights = $mias->map(sub{$_->weight})->grep(sub{defined $_});
    # Average sequence identity of all the templates.
    # NB linker domains are counted multiple times. 
    # Given a hub proten and three interacting spoke proteins, there are not 4
    # values for sequence identity, but rather 6=2*(3 interactions)
    $stats->{'ifaceconsmin'} = $weights->min;
    $stats->{'ifaceconsmax'} = $weights->max;
    $stats->{'ifaceconsmed'} = median($weights);

    # Linker superpositions required to build model by overlapping dimers
    my $superpositions = $model->superpositions->values;
    # Sc scores of all superpositions done
    my $scs = $superpositions->map(sub{$_->scores->at('Sc')});
    $stats->{'scmin'} = $scs->min;
    $stats->{'scmax'} = $scs->max;
    $stats->{'scmed'} = median($scs);

    # Globularity of entire model
    $stats->{'glob'} = $model->globularity();

    # Fraction overlaps between domains for each new component placed, averages
    my $overlaps = $model->clashes->values;
    $stats->{'olmin'} = $overlaps->min;
    $stats->{'olmax'} = $overlaps->max;
    $stats->{'olmed'} = median($overlaps);

    # Number of closed rings in modelled structure, using known interfaces
    $stats->{'ncycles'} = $model->ncycles();

    my ($rmsd, $matrix) = modelrmsd($model, $target);
    $rmsd = 'NaN' unless defined $matrix;
    $stats->{'rmsd'} = $rmsd;

    # Intrinsic model score
    my $score = $model->score;
    $stats->{'score'} = $score;

    # Format floating point values
    foreach my $key (@$floatkeys) {
        my $value = $stats->{$key};
        $stats->{$key} = sprintf("%.2f",$value) if defined $value;
    }

    $model->scores->put('benchstats', $stats);
    return ($stats);
}



sub modelrmsd {
    my ($model, $target) = @_;

    my $benchrmsd = $model->scores->at('benchrmsd');
    my $benchmatrix = $model->scores->at('benchmatrix');
    my $benchmapping;
    unless (!$ops{'debug'} && !$ops{'redo'} && 
            defined $benchrmsd && defined $benchmatrix) {
        $model->scores->delete('benchrmsd');
        $model->scores->delete('benchmatrix');
        ($benchmatrix, $benchrmsd, $benchmapping) = $model->rmsd_class($target);
        if (defined $benchmatrix) {
            $model->transform($benchmatrix);
            $model->scores->put('benchrmsd', $benchrmsd);
            $model->scores->put('benchmatrix', $benchmatrix);
            $model->correspondance($benchmapping);
        } else {
            $benchrmsd = 'NaN';
        }
    }
    
    return wantarray ? ($benchrmsd, $benchmatrix) : $benchrmsd;
}


sub modeloutputs {
    my ($target, $model) = @_;

    my $acc = $target->id;
    my $mbase = $acc . '-' . sprintf("%05d",$model->class);
    mkdir $acc;
    my $pdbfile = "${acc}/${mbase}.pdb.gz";
    my $domfile = "${acc}/${mbase}.dom";
    my @files = ($pdbfile, $domfile);
    my @locks = map { "$_.NFSLock" } @files;
    my $alldone = 1;
    foreach (@files) {
        unless (-e $_ || -e "$_.NFSLock") { $alldone = 0 }
    }
    return if $alldone;

    _domfile($domfile, $model, $target);
    _pdbfile($pdbfile, $model, $target);

} # modeloutput


sub _domfile {
    my ($domfile, $model, $target) = @_;

    if (-s $domfile) {
        return;
    }
    my $write_target = 
        $model->scores->exists('benchrmsd') && 
        $model->scores->at('benchrmsd') > 0;

    my $lock = File::NFSLock->new($domfile,LOCK_EX|LOCK_NB) or return;

    my $domio = new SBG::DomainIO::stamp(file=>">$domfile");
    my $keys = [ $model->coverage($target) ];
    my $mapping = $model->correspondance;

    foreach my $key (@$keys) {
        # Write in tandem (model, target, model, target)
        $domio->write($model->domains([$key]));
        $domio->write($target->domains([$mapping->{$key}])) if $write_target;
    }
}


sub _pdbfile {
    my ($pdbfile, $model, $target) = @_;
    if (-s $pdbfile) {
        return;
    }
    my $write = 
        $model->scores->exists('benchrmsd') && 
        $model->scores->at('benchrmsd') > 0;

    return unless $write;

    my $lock = File::NFSLock->new($pdbfile,LOCK_EX|LOCK_NB) or return;

    my $pdbio = new SBG::DomainIO::pdb(file=>">${pdbfile}", compressed=>1);

    # Only show common components
    my $keys = [ $model->coverage($target) ];

    # Treat model complex as single domain
    my $modelasdom = $model->combine(keys=>$keys);

    my $mapping = $model->correspondance;
    my $mapped_keys = [ map { $mapping->{$_} } @$keys ];
    # Get target complex as single domain
    my $targetasdom = $target->combine(keys=>$mapped_keys);

    # Write model first
    $pdbio->write($modelasdom, $targetasdom);

}