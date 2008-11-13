#!/usr/bin/env bash

SRC=`echo $1 | tr "[:upper:]" "[:lower:]" `
REF=`echo $2 | tr "[:upper:]" "[:lower:]" `
DIR=$3

if [ "$SRC" == "$REF" ]; then 
    exit 0;
fi

if [ ! -z "$DIR" ]; then
    mkdir -p $DIR
else
    # Use temp dir if none given
    DIR=`mktemp -t -d assembly.tmp.XXXX`
fi

cd $DIR
#echo $PWD

pdbc -d $SRC > $SRC.dom
pdbc -d $REF > $REF.dom
#pdbc -d $DST > $DST.dom

cat $SRC.dom $REF.dom > $SRC-$REF.dom
do_stamp $SRC-$REF.dom > $SRC-$REF.trans

# NB $REF must have a lowercase chain ID
pickframe -f $SRC-$REF.trans -i $REF > $SRC-$REF-FoR.trans

# This is the transformation
# But it still has a } character at the end

# Whole domain block
#cat $SRC-$REF-FoR.trans | egrep -v "(%|0.00000|$REF) "
#cat $SRC-$REF-FoR.trans | egrep -v "(%|0.00000|$REF)" > $SRC-$REF-FoR.dom

# Or just the transformation matrix
# cat $SRC-$REF-FoR.trans | egrep -v "(%|0.00000|$SRC|$REF)" | tr -d '}'

# Strip out the reference domain, but not the source, as it has the filename
cat $SRC-$REF-FoR.trans | \
     egrep -v "(%|0.00000|$SRC|$REF)" | \
#    egrep -v "(%|0.00000|$REF)" | \
    tr -d '}' > $SRC-$REF-FoR-s.csv

echo $DIR/$SRC-$REF-FoR-s.csv

