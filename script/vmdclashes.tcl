#!/usr/bin/env vmd -dispdev text -e

# Created by Leonardo Trabuco <ltrabuco@gmail.com>
# Modified by Chad Davis

set curfile [lindex $argv 0]
mol new $curfile waitfor all

set sel [atomselect top all]
      
set natoms [$sel num]
puts "natoms=$natoms"

# Within 2.0 angstrom
set distthresh 2.0
set contacts [measure contacts $distthresh $sel]
$sel delete
 
set nclashes [llength [lindex $contacts 0]]
puts "nclashes=$nclashes"

set pcclashes [expr 100.0 * $nclashes / $natoms]  
puts "pcclashes=$pcclashes"

quit
