#!/usr/bin/env perl

=head1 NAME

B<evalmodels.pl> - Create CSV table output of model statistics

=head1 SYNOPSIS

evalmodels model1.model model2.model ...

=head1 DESCRIPTION


=head2 SPECIFIC OPTIONS


=head2 -redo 1

Recalculates all derived statistics, rather than using cached values.


=head1 GENERIC OPTIONS

=head2 -h | -help 

Print this help page

=head2 -l | -log <LOG-LEVEL>

Set logging level

In increasing order: TRACE DEBUG INFO WARN ERROR FATAL

I.e. setting B<-l WARN> (the default) will log warnings errors and fatal
messages, but no info or debug messages to the log file (B<log.log>)

=head2 -f | -file <Log file>

Default: <network name>.log in current directory

=head2 -blocksize <N>

Number of file arguments given on the command line to be processed by each PBS job. 

Default: 1

-blocksize 100 : every 100 files given on the command line will be processed in one synchronous PBS job. 

-blocksize 1 : every single input file is the input to a single PBS job


=head2 -J 

PBS array job

Identifies the only command line argument to a file from which to read the input files from. This is most useful when there are more files than can be written on the command line, as that is limited.

=head2 -directives "<directive1> <directive2> ..."

PBS directives to be passed to B<qsub>

E.g.

 -directives "-l cput=04:59:00"

Note that the directives must be quoted.

=head2 -d 1 | -debug 1

Set debug mode. 


=head2 -c 0 | -cache 0

Disable caching. On by default.



=head1 SEE ALSO



=cut


use strict;
use warnings;

# Local libraries
use FindBin qw/$Bin/;
use lib "$Bin/../lib/";

# Send this off to PBS first, if possible, before loading other modules
use SBG::U::Run 
    qw/frac_of getoptions start_lock end_lock @generic_options/;

# Options must be hard-coded, unfortunately, as local variables cannot be used
use PBS::ARGV @generic_options, 
    qw/redo=i/;
# the 'models' base directory
my %ops = getoptions @generic_options,
    qw/redo=i/;
    

use Moose::Autobox;
use autobox::List::Util;
use List::MoreUtils qw/mesh/;
use File::Basename;
use Log::Any qw/$log/;
use File::NFSLock;
use Fcntl qw/LOCK_EX LOCK_NB/;
use PDL::Lite;
use Data::Dumper;
use File::Spec::Functions;

use SBG::U::Object qw/load_object/;
use SBG::U::Log;
use SBG::U::List qw/mean avg wtavg median sum min max flatten argmax argmin between/;
use SBG::Run::pdbc qw/pdbc/;
use SBG::DomainIO::stamp;
use SBG::DomainIO::pdb;
use SBG::NetworkIO::sif;
use SBG::NetworkIO::png;

use SBG::U::Map qw/uniprot2gene/;


# Backwards compat.
$ops{'redo'} = 1 if defined($ops{'cache'}) && $ops{'cache'} == 0;


# Column header labels
# This is the printing order
my $tkeys = [ qw/tid tdesc tndoms tniactions tseqlen/ ];
my $allkeys = [ 
    @$tkeys,
    qw/mid/,
    qw/homology/,
    
    qw/rmsd/,
    qw/score/,
#    qw/difficulty/,
    qw/pcclashes/,
    qw/mndoms pcdoms mniactions pciactions mseqlen pcseqlen/,
#    qw/n100 n80 n60 n40 n0/,
#    qw/ndockgreat ndockless/,

    qw/nsources/,
    qw/ncycles/,
    qw/pcburied/,
    qw/glob/,
    
    qw/scmax scmed scmin/,
    qw/idmax idmed idmin/,
    qw/dockmax dockmed dockmin/,
    qw/iptsmax iptsmed iptsmin/,
    qw/ifacelenmax ifacelenmed ifacelenmin/,
    qw/iweightmax iweightmed iweightmin/,
    qw/seqcovermax seqcovermed seqcovermin/,
#     qw/sas/,
    qw/olmax olmed olmin/,
    qw/genes/,
    ];
    
# Keys that should be round to 2 decimal places
my $floatkeys = 
    [ qw/rmsd score difficulty pcdoms pcseqlen glob pcburied idmin idmax idmed pcclashes
    iweightmin iweightmax iweightmed
    seqcovermin seqcovermax seqcovermed  
    olmin olmax olmed/ ];


unless (-r $ARGV[0]) {
	print STDERR "No model found at: $ARGV[0]\n";
	exit;
}


my $headerpath = '00-header.csv';
unless (-s $headerpath) {
    open my $fh, '>', $headerpath;
    print $fh $allkeys->join("\t"), "\n";
}


my $log_handle;
foreach my $file (@ARGV) {
    if (defined($ops{'J'})) {
        # The file is actually the Jth line of the list of files
        $file = PBS::ARGV::linen($file, $ops{'J'});
    }

    next unless -r $file;
    
    # Where we are
    my $basename = basename($file,'.model');
    my $dirname = basename dirname $file;
    mkdir $dirname;
    my $basepath = catfile($dirname, $basename);
    my $output = $basepath . '.csv';
    # Skip if already finished
    next if !$ops{'redo'} && -e $basepath . '.done';

    # Lock this model from other processes/jobs
    my $lock = start_lock($output);
    next if ! $lock && ! $ops{'redo'};

    Log::Any::Adapter->remove($log_handle);
    # A log just for this input file:
    $log_handle = Log::Any::Adapter->set(
        '+SBG::Log',level=>'trace',file=>$output . '.log');
    
    # Mark jobs that are tried, but not done, this file deleted when finished
    # A cheap way to track what crashes before finishing
    my $tryingfile = $output . '.trying';
    open my $tryingfh, ">$tryingfile";
    close $tryingfh;

    my $stats = {};    
    if (-e $file) {
        do_model($file, $stats);
     }
     
    end_lock($lock, 1);
    unlink $tryingfile;
}


sub do_model {
    my ($modelfile, $stats) = @_;
    
    $log->info("modelfile: $modelfile");
    my $model = load_object($modelfile);
    $model->{'modelfile'} = $modelfile;

    $stats = $model->scores;
    
    if ($ops{'redo'}) {
        $log->info("redo");

        # Clear everything, including the superposition
#        $model->clear();


        $model->clear_score();
        $model->clear_score_weights();
        $model->clear_score_keys();
        # TODO
        # and vmdclashes
#        $model->clear_vmdclashes();
 
        # Just save the rmsd
        my $rmsd = $model->scores->at('rmsd');
        $model->clear_homology;
        $model->clear_network;
        $model->clear_scores;
        # Calling scores() here rebuilds it
        $model->scores->put('rmsd', $rmsd);
        $stats->{'rmsd'} = $rmsd;
        
        $model->store($modelfile);
        $log->info("model stats and RMSD wiped an re-saved");
    }
        
        
    $stats->{'score'} = $model->score();
       
    # Get Genenames (TODO DES need to be a separate annotation module)
    my $dommodels = $model->models->values;
    my $inputs = $dommodels->map(sub{$_->input || $_->query});
    my $genes = $inputs->map(sub{uniprot2gene($_->display_id)});
    $stats->{'genes'} = $genes->join(',');
   
    # TODO DEL why is this missing?
    $stats->{'mid'} ||= $model->modelid; 

    # TODO DES to become ComplexIO::csv
    # Format floating point values, just use 'sprintf %g'
    foreach my $key (@$floatkeys) {
        my $value = $stats->{$key};
#        $stats->{$key} = sprintf("%.2f",$value) if defined $value;
        $stats->{$key} = sprintf("%g",$value) if defined $value;        
    }
    
    my $basepath = _basepath($model);
    open my $fh, ">${basepath}.csv" or die;
    # Print the CSV line, using predefined key ordering
    my $fields = $stats->slice($allkeys)->map(sub{defined $_?$_:''});
    print $fh $fields->join("\t"), "\n";
    close $fh;
    
    modeloutputs($model);

    # Save any changes
    $model->store($modelfile);
} # do_model


sub _basepath {
    my ($model) = @_;
    my $targetid = $model->targetid;
    my $modelid = $model->modelid;
    mkdir $targetid;
    my $basepath = catfile($targetid, $modelid);
    return $basepath;    
}




# How interesting (i.e. difficult) is the model, [0:100]
sub _difficulty {
	my ($stats) = @_;
	my @values;
	push @values, 100.0 - ($stats->{'idmax'} || 0);
	push @values, $stats->{'mndoms'};
	push @values, $stats->{'pseqlen'};
	push @values, 100.0 * $stats->{'nsources'} / ($stats->{'tndoms'} - 1);
	push @values, 100.0 * $stats->{'ncycles'} / $stats->{'mndoms'};
	
	my $classes = [ qw/n0 n40 n60 n80 n100 ndockless ndockgreat/ ];
	my $class_present = $classes->map(sub{$stats->{$_} > 0});
	push @values, 100.0 * $class_present->sum / $classes->length;
	
	# Feeling for how important the various measures are, relative to eachother
	my $weights = [ 1, 10, 2, 4, 3, 2 ];
	return wtavg(\@values, $weights);  
}




sub modeloutputs {
    my ($model) = @_;
    my $target = $model->target;
    my $basepath = _basepath($model);
        
    my $pdbfile = "${basepath}.pdb";
    my $domfile = "${basepath}.dom";
    my $siffile = "${basepath}.sif";
    my $dotfile = "${basepath}.png";
    my @files = ($pdbfile, $domfile, $siffile, $dotfile);
    my @locks = map { "$_.NFSLock" } @files;
    my $alldone = 1;
    foreach (@files) {
        unless (-e $_ || -e "$_.NFSLock") { $alldone = 0 }
    }
    return if $alldone;

#    _domfile($domfile, $model, $target);
    _pdbfile($pdbfile, $model, $target);
#    _siffile($siffile, $model);
#    _dotfile($dotfile, $model);

} # modeloutput


sub _siffile {
    my ($siffile, $model) = @_;

    if (-s $siffile) {
        return;
    }

    my $lock = File::NFSLock->new($siffile,LOCK_EX|LOCK_NB) or return;

    my $sifio = SBG::NetworkIO::sif->new(file=>">$siffile");
    $sifio->write($model->network);
    
} # _siffile


sub _dotfile {
    my ($dotfile, $model) = @_;

    if (-s $dotfile) {
        return;
    }

    my $lock = File::NFSLock->new($dotfile,LOCK_EX|LOCK_NB) or return;

    my $dotio = SBG::NetworkIO::png->new(file=>">$dotfile");
    $dotio->write($model->network);
    
} # _dotfile


sub _domfile {
    my ($domfile, $model, $target) = @_;

    if (-s $domfile) {
        return;
    }
    $log->debug($domfile);
    my $write_target = 
        $model->scores->exists('benchrmsd') && 
        $model->scores->at('benchrmsd') > 0;

    my $lock = File::NFSLock->new($domfile,LOCK_EX|LOCK_NB) or return;

    my $domio = new SBG::DomainIO::stamp(file=>">$domfile");
    my $keys = $write_target ? [ $model->coverage($target) ] : $model->keys;
    my $mapping = $model->correspondance;

    # Header details
    my $report;
    my $reportio = SBG::ComplexIO::report->new(string=>\$report);
    $reportio->write($model);
    $reportio->close;
    # Prepend a comment
    $report =~ s/^/% /gm;
    my $fh = $domio->fh();
    print $fh $report;

    foreach my $key (@$keys) {
        # Write in tandem, with model first: (model, target, model, target, ...)
        $domio->write($model->domains([$key]));
        $domio->write($target->domains([$mapping->{$key}])) if $write_target;
    }
} # _domfile

use Data::Dumper;
sub _pdbfile {
    my ($pdbfile, $model, $target) = @_;
    if (-s $pdbfile) {
        return;
    }
    my $rmsd = $model->scores->at('rmsd');
    my $write_target = defined($target) && defined($rmsd) && $rmsd >= 0;

    $log->debug("$pdbfile write_target: $write_target rmsd: $rmsd") if $rmsd;

    my $lock = File::NFSLock->new($pdbfile,LOCK_EX|LOCK_NB) or return;

    # Header details
    my $report;
    my $reportio = SBG::ComplexIO::report->new(string=>\$report);
    $reportio->write($model);
    $reportio->close;
    # Prepend a comment
    $report =~ s/^/REMARK /gm;

    
    # Only show common components
    my $keys = $write_target ? [ $model->coverage($target) ] : $model->keys;  

    my $mapping = $model->correspondance;
    my $mapped_keys = [ map { $mapping->{$_} } @$keys ];

#    my $pdbio = new SBG::DomainIO::pdb(file=>">${pdbfile}", compressed=>1);
    my $pdbio = new SBG::DomainIO::pdb(file=>">${pdbfile}", compressed=>0);
    my $fh = $pdbio->fh();
        
    print $fh $report;
    $pdbio->flush;
    
    my $combine = 0;
    if($combine) {
    	# Treat model complex as single domain, if compared to target
        my $modelasdom = $write_target ? 
            $model->combine(keys=>$keys) : $model->domains;
        # Get target complex as single domain
        my $targetasdom = $write_target ? 
            $target->combine(keys=>$mapped_keys) : undef;
	    # Write model first 
	    # (in Rasmol, first is blue, second is red)
	    # (in Pymol, first is green, second is cyan)
	    if ($write_target) {
	        $pdbio->write($modelasdom, $targetasdom);
	    } else {
	        $pdbio->write($modelasdom);
	    }

    } else {
    	my $models = $model->domains($keys);
    	my @list;
    	if ($write_target) {
        	# Get only the subset modelled, and map to the corresponding chains
        	my $targets = $target->domains($keys, $mapping);
    	   # Print alternately, Model A, Target A, Model B, Target B, ...  	
    	   @list = mesh(@$models, @$targets);
    	} else {
    		@list = @$models;
    	}
    	$pdbio->write(@list);
    	
    }

} # _pdbfile

