
# Library paths are always appended rathern than prepended.
# They will not over-ride your own libraries

# Get location of this script
BASE=`dirname ${BASH_SOURCE[0]}`

export PERL5LIB="$PERL5LIB:$BASE/lib"

# If STAMPDIR is not already set, default:
export STAMPDIR=${STAMPDIR:=/g/russell1/apps/stamp.4.3/defs}

export PATH=$PATH:/g/russell1/lbin

complete -o default -C 'sbgobj -options' sbgobj


