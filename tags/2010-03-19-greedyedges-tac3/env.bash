
# Library paths are always appended rathern than prepended.
# They will not over-ride your own libraries

# Enable bash programable completion
shopt -s progcomp
# And don't break words on a colon :
export COMP_WORDBREAKS=${COMP_WORDBREAKS//:}
# When sbgobj is on the prompt and TAB comes, runs 'sbgobj -options'.
# default: anything unrecogized can be completed with regular file completion
complete -o default -C 'sbgobj' sbgobj


