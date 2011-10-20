#!/usr/bin/env bash

# A simplified version of update_blastdb.pl (provided by NCBI)

# Rather then download the pre-formatted DBs, this makes the DB from the fasta files

wget='/usr/bin/wget --timestamping --no-directories --no-host-directories --no-parent --limit-rate=100k --wait=5 --random-wait'
ncbi=ftp://ftp.ncbi.nih.gov/blast/db
quiet='--quiet'
#quiet=
db=${1:-pdbaa}
$wget $quiet --no-directories $ncbi/FASTA/$db.gz || exit
# Verify MD5 signature (there is no --quiet option on speedy's md5sum)
$wget $quiet $ncbi/FASTA/$db.gz.md5  || exit
md5sum ${db}.gz.md5 > /dev/null || exit

# Original Blast uses formatdb
if type -p formatdb > /dev/null ; then
    # (-p T for proteins, -o T to index fasta IDs, -n names the database)
    cmd="formatdb -i /dev/stdin -p T -o T -n $db"
# Blast+ uses makeblastdb
elif type -p makeblastdb > /dev/null ;then
    # Default sequence type is protein
    cmd="makeblastdb -in - -out $db -title $db -parse_seqids"
else
    echo "Neither formatdb nor makeblastdb found";
    exit;
fi

# Use zcat to keep the gzipped database
zcat $db.gz | $cmd


