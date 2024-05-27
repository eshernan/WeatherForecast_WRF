#!/bin/bash
if [ [ -z "${SIMULATION_DATE}" ] ] ; then
    echo "Using the following Simulation Date $SIMULATION_DATE"
else 
	export SIMULATION_DATE=`echo $(date +"%Y%m%d")-00`
   echo "Using the following Simulation Date $SIMULATION_DATE"
fi
