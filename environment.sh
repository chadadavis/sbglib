
# Intro ...

# Library paths are always appended rathern than prepended.
# They will not over-ride your own libraries

# Get location of this script
BASE=`dirname $0`

export PERL5LIB="$PERL5LIB:$BASE/perl"
export PYTHONPATH="$PYTHONPATH:$BASE/python"
export R_LIBS="$R_LIBS:$BASE/r"

# TODO think of better system here
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$BASE"

