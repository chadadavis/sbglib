#!/usr/bin/env perl

=head1 NAME

B<SBG::U::Complete> - Tools for shell command line TAB completion 

=head1 SYNOPSIS

# NB requires bash cmd: complete  -o default -C scriptname scriptname

use SBG::U::Complete qw/complete_methods/;

use Getopt::Complete ( 
    # On/Off options (either set or unset, no values)
    'keep!'      => undef,
    'help!'      => undef,
    # List all possible values, e..g --log=TRACE
    'log=s'      => [ qw/TRACE DEBUG INFO WARN ERROR FATAL/ ],
    # For everything else that's not a file, try method name completion
    # I.e. if do: myscript.pl some_obj.stor TAB
    # And some_obj.stor is a Storable or Data::Dump(er) object, it's methods
    # are completable
    '<>'         => \&complete_methods,
    );

# What options did we get:
print "help\n" if $ARGS{help};

# Remaninig non-option parameters, i.e. filenames, etc.
my @bare_args = @{$ARGS{'<>'}};


=head1 DESCRIPTION


=head1 SEE ALSO

L<Getopt:Complete>

=cut



package SBG::U::Complete;

use base qw/Exporter/;
our @EXPORT_OK = qw/complete_methods/;

use SBG::U::Object qw/methods load_object/;

sub complete_methods {
    my ($cmd, $current, $opt, $ops) = @_;
    my @objects = @{$ops->{'<>'}};
    my $last = $objects[-1];
    return [] unless defined $last;
    # Actual program is being run, not tab completion
    return \@objects if $opt =~ /<>/; 
    # Get methods;
    my $obj = SBG::U::Object::load_object($last);
    my @methods = SBG::U::Object::methods($obj);
    return \@methods;

} # 



1;

