#!/bin/bash
#. /home/run/.bash_profile
datepath=/usr/bin
################################################################
# Validate if is used a custom hour
################################################################
if [ "$1" ] 
 then 
	hoursInt=$1
else
	hoursInt=${hours#0}
fi
################################################################
currenttime=`$datepath/date --utc +%Y-%m-%d`

################################################################
# timeframedays define the number of days that will be deleted
################################################################
timeframedays=20

################################################################
# BASE_PATH define the path where the files will be deleted
# DATA_PATH define the path where the files will be deleted
# PROCESS_PATH define the path where the files will be deleted
################################################################
BASE_PATH=/nfs/users/working/wrf4
DATA_PATH=$BASE_PATH/data
PROCESS_PATH=$BASE_PATH/corridas


#####################################################################
# percentOfUse define the percent of use of the filesystem /nfs/users/
# if the filesystem use is greater than 90% the files will be deleted 
#####################################################################
percentOfUse=`df -kh $BASE_PATH | awk 'NR==2''{print $5}' | tr -d '%'`

#####################################################################
# validate if filesystem use is greater than 90%
#####################################################################
function validateFileUse() {
if [ $percentOfUse -gt 90 ]; then
        logger "The filesystem need clean files" "INFO"
        logger "The following files will be deleted" "INFO"
        find  $DATA_PATH -type d -mtime +$timeframedays -maxdepth 2 -mindepth 2
        find  $PROCESS_PATH -type d -mtime +$timeframedays -maxdepth 2 -mindepth 2
        deleteOldFiles
else
        logger "The filesystem don't need clean files" "INFO"
        logger "The percent of use is $percentOfUse" "INFO"
        deleteOldFiles

fi         
        
}

###################################################################
# deleteOldFiles delete the old files that are older than $timeframedays
# delete the forst level and deep level folders of 
# $DATA_PATH and $PROCESS_PATH
###################################################################
function deleteOldFiles {
   logger "Deleting old files" "INFO"
   for folder in `find /nfs/users/working/wrf4/data/  -maxdepth 1 -mindepth 1 -type d -mtime +$timeframedays`; 
        do rm -Rf  $folder ; 
   done
   logger "Old files deleted" "INFO"
}

function logger(){
   message="$1"
   status="$2"
   printf "$year$month$day$hours$minute ${status}: ${message}\n"

}


validateFileUse
