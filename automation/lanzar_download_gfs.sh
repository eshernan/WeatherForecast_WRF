#!/bin/bash

datepath=/usr/bin
year=`$datepath/date --utc +%Y`
month=`$datepath/date --utc +%m`
day=`$datepath/date --utc +%d`
hours=`$datepath/date --utc +%H`
minute=`$datepath/date --utc +%M`


if [ "$1"] 
 then 
	hoursInt=$1
else
	hoursInt=${hours#0}
fi

###############################################################
# This variables should used on all path for install or use of 
###############################################################
BASE_PATH=/nfs/users/working/wrf4/control
AUTOMATION_BASE=$BASE_PATH/automation
##############################################################


#esta linea es opcional puedes dejar en nombre de un proceso especifico
#busca un proceso especifico
#pgrep -x /opt/scripts/download_gfs.sh
#ps -ef | grep -v grep | grep /opt/scripts/download_gfs.sh
ps -ef | grep -v grep | grep $AUTOMATION_BASE/getGFS_aria.sh
#echo $? returna 0 si el proceso existe sino returna otro valor
DATO="$?"
if (($DATO!=0));

then
#aqui puedes especificar el proceso que vas iniciar
#como ./apache2 start
echo "iniciar proceso"
#hoursInt=16
echo " Hora a procesar $hoursInt, en Hora Local $date "

if [ ! -n "$hoursInt" ]; then 
   echo "Error: Hora no valida --$hoursInt"
   exit 1;
fi 

if [[ $hoursInt -ge 1 ]]  && [[ $hoursInt -le 6 ]]; then
   hora=00
elif [[ $hoursInt -ge 7 ]]  && [[ $hoursInt -le 12 ]]; then
   hora=06
elif [[ $hoursInt -ge 13 ]]  && [[ $hoursInt -le 18 ]]; then
   hora=12
elif [[ $hoursInt -ge 19 ]]  && [[ $hoursInt -le 23 ]]; then
   hora=18
elif [[ $hoursInt -eq 0 ]];then
   hora=00
fi

#/opt/scripts/getGFS_aria.sh -d=$year$month$day -r=$hora -wl=-95.0 -el=-50.0 -sl=-20.5 -nl=25.5 -st=0 -et=72 -f1="$year""$month""$day"-$hora

TARGET="https://nomads.ncep.noaa.gov/cgi-bin/filter_gfs_0p25.pl"
TARGET2='ftp://ftp.ncep.noaa.gov/pub/data/nccf/com/gfs/prod/'

if curl --output /dev/null --silent --head --fail "$TARGET"
then
   ps -ef | grep -v grep | grep $AUTOMATION_BASE/getGFS_aria.sh
   DATO="$?"
   if (($DATO!=0));
   then
       echo "descargando filtered GFS..."
       $AUTOMATION_BASE/getGFS_aria.sh -d=$year$month$day -r=$hora -wl=-95.0 -el=-50.0 -sl=-20.5 -nl=25.5 -st=0 -et=72 -f1="$year""$month""$day"-$hora
   else
        echo "Hay proceso de descarga por filter"
   fi
else
   echo $TARGET" Not Exists"
   echo "DEscargando archivos completos de $TARGET2"
   ps -ef | grep -v grep | grep $AUTOMATION_BASE/downcep_nomad8.sh
   DATO="$?"
   if (($DATO!=0));
   then
       echo "descargando full GFS..."
       $AUTOMATION_BASE/downcep_nomad8.sh
   else
        echo "Hay proceso de descarga por full"
   fi

fi



else
echo "el proceso se esta ejecutando"
fi
#fin del script

