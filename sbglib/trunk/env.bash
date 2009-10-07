
# Library paths are always appended rathern than prepended.
# They will not over-ride your own libraries

# Get location of this script (bash ver 2 cannot do this)
if ((${BASH_VERSINFO[0]} >= 3)); then
    BASE=`dirname ${BASH_SOURCE[0]}`
    export PERL5LIB="$PERL5LIB:$BASE/lib"
fi

# If STAMPDIR is not already set, default:
if [ -z "$STAMPDIR" ]; then 
    export STAMP="/g/russell1/apps/stamp.4.4"
    export STAMPDIR="$STAMP/defs"
    export PATH=$PATH:$STAMP/bin/`uname -m`
fi

complete -o default -C 'sbgobj -options' sbgobj


