#!/usr/bin/env perl


use File::Temp qw(tempfile);


exit(main(@ARGV));

################################################################################

sub main {
    my ($pdbid, $modeldom) = @_;

    my (undef, $pdbdom) = tempfile();

    my $cmd;

    # Get a domain file for the true structure
    $cmd = "pdbc -d $pdbid > $pdbdom";
    `$cmd`;
    unless (-r $file && -s $pdbdom) {
        print STDERR "Failed: $cmd\n";
        return;
    }

    # Generate CofM (PDB format) files for two domain files (true, model)
    $cmd = "cofm -f $pdbdom > ${pdbdom}.cofm";
    `$cmd`;
    # TODO check file size

    $cmd = "cofm -f $modeldom > ${modeldom}.cofm";
    `$cmd`;
    # TODO check file size    

    # RMSD of two CofM files.
    # OR just do_stamp them?



}
