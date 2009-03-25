
This repository houses code common to Bioinformatics-related developement in the SBG (Structural Bioinformatics Group) at EMBL.


See (Intranet):
http://www.russell.embl.de/private/wiki/index.php/libSBG

################################################################################
Setup:

Set what shell you are running with:

 echo $SHELL

bash: You simply need to source env.bash (from your ~/.bashrc)

tcsh: Add to your ~/.cshrc :

 setenv DIR=<the directory where this readme is located>
 setenv PERL5LIB $PERL5LIB:$DIR
 setenv PATH $PATH:$DIR/bin

################################################################################
API Documentation:

To get the documentation for a given module, e.g. SBG::Root, just do:

perldoc SBG::Root

This works as long as your library paths are set correctly. See the blurp on setting up your environment above.

--
Chad Davis
davis@embl.de
2009-01-01

