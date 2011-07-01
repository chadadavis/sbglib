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
use PDL::Lite;


# Local libraries
use FindBin qw/$Bin/;
use lib "$Bin/../lib/";

use PBS::ARGV qw/qsub/;
use SBG::U::Object qw/load_object/;
use SBG::U::Log;
use SBG::U::List qw/mean avg median sum min max flatten argmax argmin/;
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
    qw/ntransdb ndom_dom ntemplates nstruct ndocking/,
#     qw/pias/,
    qw/nsources/,
    qw/ncycles/,
    qw/scmin scmax scmed/,
    qw/glob/,
    qw/idmin idmax idmed/,
    qw/ifacelenmin ifacelenmax ifacelenmed/,
    qw/ifaceconsmin ifaceconsmax ifaceconsmed/,
    qw/seqcovermin seqcovermax seqcovermed/,
#     qw/sas/,
    qw/olmin olmax olmed/,
    ];
    
my $scorekeys = [
    qw/mndoms  mseqlen pdoms   pseqlen  nsources    ncycles/,
    qw/scmin   scmax   scmed/,
    qw/glob/,
    qw/idmin   idmax   idmed/,
    qw/ifacelenmin ifacelenmax ifacelenmed/,
    qw/ifaceconsmin    ifaceconsmax    ifaceconsmed/,
    qw/olmin   olmax   olmed/,
    ];
    

# The final field is for the constant, requires appending a '1' to the scores
my $scoreweights = pdl qw/0.43974326 0.00094791232 -0.019256422 0.023119807 0.19064436 -0.80326193 0.0044039123 0.020716519 -0.11126529 -0.029866833 -0.12870892 0.11697604 0.047743678 -0.017364881 -0.010622602 -0.0022507497 -0.029951434 -0.098814945 -0.0068636601 1.5286585 -12.615978 8.8859358 10.618353/;
    

# Keys that should be round to 2 decimal places
my $floatkeys = 
    [ qw/rmsd score pdoms pseqlen glob idmin idmax idmed 
    ifaceconsmin ifaceconsmax ifaceconsmed
    seqcovermin seqcovermax seqcovermed  
    olmin olmax olmed/ ];

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
    next if !$ops{'debug'} && !$ops{'redo'} && -e $basepath . '.done';

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
    my $target;
    my $stats = {tid => $tid};
    if (-r $targetfile) {
        $log->debug("targetfile: $targetfile");
        $target = load_object($targetfile);
        $target->id($tid) unless defined $target->id;
        $target->store($targetfile);
    } else {
            $log->info(
            "No target file: $targetfile. Specify via: -target <target>");
    }
    
    if (-e $file) {
        do_model($target, $file, $stats);
#    } else {
#        # If no models were produced, just a print a truncated header
#        open my $fh, ">${tid}/${tid}-00000.csv";        
#        print $fh $stats->slice($tkeys)->join("\t"), "\n";
#        close $fh;
     }
     
    end_lock($lock, 1);
    unlink $tryingfile;
}


sub do_model {
    my ($target, $modelfile, $stats) = @_;
    $log->debug($modelfile);
    $log->info("modelfile: $modelfile");
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
    
    modeloutputs($target,$model,$dirname);

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
    my $tid = $stats->{'tid'};
    $tid ||= $target ? $target->id : undef;
    ($tid) = $model->id =~ /^(.*?)-\d+$/ unless $tid;
    $stats->{'tid'} = $tid;
    $model->target($tid);
    
    $stats->{'tdesc'} = $model->description;    

    # Number of Components that we were trying to model
    my @tdoms = flatten $model->symmetry;
    my $tndoms = @tdoms;
    $stats->{'tndoms'} = $tndoms;
    # Number of domains modelled 
    my $dommodels = $model->models->values;
    my $mndoms = $stats->{'mndoms'} = $dommodels->length;
    # Percentage of component coverage, e.g. 3/5 components => 60
    $stats->{'pdoms'} = 100.0 * $mndoms / $tndoms;


    # TODO need to grep for defined($_) ? (also for n_res ? )
    my $ids = $dommodels->map(sub{$_->scores->at('seqid')});
    $stats->{'idmin'} = min $ids;
    $stats->{'idmax'} = max $ids;
    $stats->{'idmed'} = median $ids;
        
    # Model: interactions
    my $mias = $model->interactions->values;
    # Model: number of interactions
    my $mnias = $stats->{'mnias'} = $mias->length;

    foreach my $source (qw/transdb dom_dom templates struct docking/) {
    	my $label = "n$source";
    	$stats->{$label} = $mias->grep(sub{$_->source eq $source})->length;
    }
    
    # Fractional residue conservations of each interaction.
    # The value for each interaction is the average of its two interfaces
    my $cons = $mias->map(sub{$_->scores->at('avg_frac_conserved')});
    $stats->{'ifaceconsmin'} = min $cons ;
    $stats->{'ifaceconsmax'} = max $cons;
    $stats->{'ifaceconsmed'} = median $cons;
    
    # Number of residues in contact in an interaction, averaged between 2
    # interfaces.
    my $nres = $mias->map(sub{$_->scores->at('avg_n_res')});
    $stats->{'ifacelenmin'} = min $nres;    
    $stats->{'ifacelenmax'} = max $nres;
    $stats->{'ifacelenmed'} = median $nres;


    # Number of template PDB structures used in entire model
    # TODO belongs in SBG::Complex
    my $idomains = $mias->map(sub{$_->domains->flatten});
    my $ipdbs = $idomains->map(sub{$_->file});
    my $nsources = scalar List::MoreUtils::uniq $ipdbs->flatten;
    $stats->{'nsources'} = $nsources;

    # This is the sequence from the structural template used
    my $mseqlen = $dommodels->map(sub{$_->subject->seq->length})->sum;
    $stats->{'mseqlen'} = $mseqlen;
    # Length of the sequences that we were trying to model, original inputs
    # TODO DEL workaround for not having 'input' set for docking templates
    my $inputs = $dommodels->map(sub{$_->input || $_->query});
    my $tseqlen = $inputs->map(sub{$_->length})->sum;
    $stats->{'tseqlen'} = $tseqlen;
    # Percentage sequence coverage by the complex model
    my $pseqlen = 100.0 * $mseqlen / $tseqlen;
    $stats->{'pseqlen'} = $pseqlen;


    # Sequence coverage per domain
    my $pdomcovers = $dommodels->map(sub{$_->coverage()});
    $stats->{'seqcovermin'} = min $pdomcovers;
    $stats->{'seqcovermax'} = max $pdomcovers;
    $stats->{'seqcovermed'} = median $pdomcovers;


    # Edge weight, generally the seqid
    my $weights = $mias->map(sub{$_->weight});
    # Average sequence identity of all the templates.
    # NB linker domains are counted multiple times. 
    # Given a hub proten and three interacting spoke proteins, there are not 4
    # values for sequence identity, but rather 2*(3 interactions) => 6
    $stats->{'ifaceconsmin'} = min $weights;
    $stats->{'ifaceconsmax'} = max $weights;
    $stats->{'ifaceconsmed'} = median $weights;

    # Linker superpositions required to build model by overlapping dimers
    my $superpositions = $model->superpositions->values;
    # Sc scores of all superpositions done
    my $scs = $superpositions->map(sub{$_->scores->at('Sc')});
    $stats->{'scmin'} = min $scs;
    $stats->{'scmax'} = max $scs;
    $stats->{'scmed'} = median $scs;

    # Globularity of entire model
    $stats->{'glob'} = $model->globularity();

    # Fraction overlaps between domains for each new component placed, averages
    my $overlaps = $model->clashes->values;
    $stats->{'olmin'} = min $overlaps;
    $stats->{'olmax'} = max $overlaps;
    $stats->{'olmed'} = median $overlaps;

    # Number of closed rings in modelled structure, using known interfaces
    $stats->{'ncycles'} = $model->ncycles();

    my ($rmsd, $matrix) = modelrmsd($model, $target);
    $rmsd = 'NaN' unless defined $matrix;
    $stats->{'rmsd'} = $rmsd;

    # Intrinsic model score
    my $score = _score($stats);
    $stats->{'score'} = $score;

    # Format floating point values
    foreach my $key (@$floatkeys) {
        my $value = $stats->{$key};
        $stats->{$key} = sprintf("%.2f",$value) if defined $value;
    }

    $model->scores->put('benchstats', $stats);
    return ($stats);    
} # model_stats


sub _score {
	my ($stats) = @_;
	my @scores = $stats->slice($scorekeys)->flatten;
	# Convet any Math::BigInt or Math::BigFloat back to scalar, for PDL
	my @nums = map { ref($_) =~ /^Math::Big/ ? $_->numify : $_ } @scores;
    # Append a '1' for the constant multiplier
    push @nums, 1;
	# Switch to PDL format
	my $values = pdl @nums;
	# Vector product
	my $prod = $scoreweights * $values;
	my $sum = $prod->sum;
	return $sum;	
}


sub modelrmsd {
    my ($model, $target) = @_;

    return unless $target;
    
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
    my ($target, $model, $tid) = @_;

    my $mbase = $tid . '-' . sprintf("%05d",$model->class);
    mkdir $tid;
    my $pdbfile = "${tid}/${mbase}.pdb.gz";
    my $domfile = "${tid}/${mbase}.dom";
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
    my $keys = $write_target ? [ $model->coverage($target) ] : $model->keys;
    my $mapping = $model->correspondance;

    foreach my $key (@$keys) {
        # Write in tandem, with model first: (model, target, model, target, ...)
        $domio->write($model->domains([$key]));
        $domio->write($target->domains([$mapping->{$key}])) if $write_target;
    }
} # _domfile


sub _pdbfile {
    my ($pdbfile, $model, $target) = @_;
    if (-s $pdbfile) {
        return;
    }
    my $write_target = 
        $model->scores->exists('benchrmsd') && 
        $model->scores->at('benchrmsd') > 0;

    my $lock = File::NFSLock->new($pdbfile,LOCK_EX|LOCK_NB) or return;

    my $pdbio = new SBG::DomainIO::pdb(file=>">${pdbfile}", compressed=>1);

    # Only show common components
    my $keys = $write_target ? [ $model->coverage($target) ] : $model->keys;
    
    # Treat model complex as single domain, if compared to target
    my $modelasdom = $write_target ? 
        $model->combine(keys=>$keys) : $model->domains;

    my $mapping = $model->correspondance;
    my $mapped_keys = [ map { $mapping->{$_} } @$keys ];
    # Get target complex as single domain
    my $targetasdom = $write_target ? 
        $target->combine(keys=>$mapped_keys) : undef;

    # Write model first (in Rasmol, first is blue, second is red)
    $pdbio->write($modelasdom);
    $pdbio->write($targetasdom) if $write_target;

} # _pdbfile
