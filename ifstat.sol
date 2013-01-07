#!/bin/ksh
#

# Initialize the Variables for Reporting
LINK_MODE="e"
LINK_STATUS="e"
LINK_SPEED="e"

# Print the Report Header (Spacing Done by Tabs)
echo "Interface	Status		Speed		Duplex"
echo "---------	------		-----		------"

for fn in `ifconfig -a |grep '^....: '|cut -d: -f1`; do

      i="`echo $fn|cut -c4`"    
      c="`echo $fn|cut -c1-3`"    

      # Set the instance of the QFE port to use
      ndd -set /dev/${c} instance $i
   
      # Set the value of the link_mode by querying link_mode
      if [ "`ndd -get /dev/${c} link_mode`" = "1" ]; then
         LINK_MODE="FULL"
      else
         LINK_MODE="HALF"
      fi
   
      # Set the value of the link_speed by querying link_speed
      if [ "`ndd -get /dev/${c} link_speed`" = "1" ]; then
         LINK_SPEED="100Mbs"
      else
         LINK_SPEED="10Mbs"
      fi
   
      # Set the value of the link_status by querying link_status_
      if [ "`ndd -get /dev/${c} link_status`" = "1" ]; then
         LINK_STATUS="UP"
      else
         LINK_STATUS="DOWN"
      fi
   
      echo "${c}${i}		${LINK_STATUS}		${LINK_SPEED}		${LINK_MODE}" 
      
   done
