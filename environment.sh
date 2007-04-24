

# Intro ...

# Library paths are always appended rathern than prepended.
# They will not over-ride your own libraries

# Get location of this script
# (This seems to work, but can it be proven?)
BASE=`dirname ${BASH_SOURCE[0]}`
#echo "EMBL Development Environment: $BASE"

export PERL5LIB="$PERL5LIB:$BASE/perl"
export PYTHONPATH="$PYTHONPATH:$BASE/python"
export R_LIBS="$R_LIBS:$BASE/r"

# TODO think of better system here
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$BASE"

