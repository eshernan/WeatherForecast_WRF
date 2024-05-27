#!/bin/bash
#. /home/run/.bash_profile

validateScript="WRFControl.sh"
pid=(`pgrep -f $validateScript`)
pid_count=${#pid[@]}
datepath=/usr/bin
year=`$datepath/date --utc +%Y`
month=`$datepath/date --utc +%m`
day=`$datepath/date --utc +%d`
hours=`$datepath/date --utc +%H`
minute=`$datepath/date --utc +%M`
rundate=`$datepath/date --utc +%Y-%m-%d`
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


pathFiles="/nfs/users/working/wrf4/data"
window00UTC=(4 5)
window06UTC=(10 12)
window12UTC=(16 18)
window18UTC=(22 23)
###############################################################
# This variables should used on all path for install or use of 
###############################################################
BASE_PATH=/nfs/users/working/wrf4/control
##############################################################
#window00UTC=(4 5 6)
#window06UTC=(8 13)
#window12UTC=(15 16 17)
#window18UTC=(20 23)

##################################################################
# Required read all env variables to executables on this script
##################################################################
#
source $BASE_PATH/scripts_op/slurm/WRF_env.sh
##################################################################
#functions
function logger(){
message="$1"
status="$2"
printf "$year$month$day$hours$minute ${status}: ${message}\n"

}
#hoursInt=4
#hora=00
URLfilter=""

#functions
function validarServer {
        ping $URLfilter -n 10
        if [ $? -ne 0 ]; then error=1 ;fi
        }
        

function downloadGFS {

      if [[ $hoursInt -ge $((window00UTC[0]-1))  ]]  && [[ $hoursInt -le window00UTC[1] ]]; then
         logger "Se descargara la hora 00" "INFO"
         logger   "El valor de las Hora es $hoursInt y el valor de UTC00   $((window00UTC[0]-1))" "INFO"
         hora=00
      elif [[ $hoursInt -ge $((window06UTC[0]-1))  ]]  && [[ $hoursInt -le window06UTC[1] ]]; then
         logger "Se descargara la hora 06" "INFO"
         logger   "El valor de las Hora es $hoursInt y el valor de UTC06   $((window06UTC[0]-1))" "INFO"
         hora=06
      elif [[ $hoursInt -ge $((window12UTC[0]-1)) ]]  && [[ $hoursInt -le window12UTC[1] ]]; then
         logger "Se descargara la hora 12" "INFO"
         logger   "El valor de las Hora es $hoursInt y el valor de UTC12   $((window12UTC[0]-1))" "INFO"
         hora=12
      elif [[ $hoursInt -ge $((window18UTC[0]-1)) ]]  && [[ $hoursInt -le window18UTC[1] ]]; then
         logger "Se descargara la hora 18" "INFO"
         logger   "El valor de las Hora es $hoursInt y el valor de UTC18   $((window18UTC[0]-1))" "INFO"
         hora=18
      else
         logger   "Validando UTC00 para $hoursInt ge UTC00-1 $((window00UTC[0]-1)) y le $((window00UTC[1]))" "INFO"
         logger   "Validando UTC06 para $hoursInt ge UTC06-1 $((window06UTC[0]-1)) y le $((window06UTC[1]))" "INFO"
         logger   "Validando UTC12 para $hoursInt ge UTC12-1 $((window12UTC[0]-1)) y le $((window12UTC[1]))" "INFO"
         logger   "Validando UTC18 para $hoursInt ge UTC18-1 $((window18UTC[0]-1)) y le $((window18UTC[1]))" "INFO"
         logger   "Hora actual no se procesara y termina la ejecucion" "ERROR"     
         exit 1 
      fi

      logger "######################################################################" "INFO"
      logger "############### Iniciando descarga de Ficheros GFS ###################" "INFO"
      logger "--------------- Descarga por Filtro -------------------" "INFO"
      TARGET="https://nomads.ncep.noaa.gov/cgi-bin/filter_gfs_0p25.pl"
      er_aria=1

		if curl --output /dev/null --silent --head --fail "$TARGET"
		then
                        ps -ef | grep -v grep | grep $BASE_PATH/automation/getGFS_aria.sh
        		DATO="$?"
        		if (($DATO!=0));
        		then
                		$BASE_PATH/automation/getGFS_aria.sh -d=$year$month$day -r=$hora -wl=-95.0 -el=-50.0 -sl=-20.5 -nl=25.5 -st=0 -et=72 -f1="$year""$month""$day"-$hora
                                er_aria="$?"
                		echo "$BASE_PATH/automation/getGFS_aria.sh -d=$year$month$day -r=$hora -wl=-95.0 -el=-50.0 -sl=-20.5 -nl=25.5 -st=0 -et=72 -f1="$year""$month""$day"-$hora"
			else
				echo "Hay proceso de descarga por filter"
			fi			
		else
    			echo $TARGET" Not Exists"
		fi 

                #if [ $er_aria -ne 0 ];then
                #logger "--------------- Descarga GFS completos -------------------" "INFO"
                #       ps -ef | grep -v grep | grep /opt/scripts/downcep_nomads8.sh
        	#	DATO="$?"
        	#	if (($DATO!=0)); then
                #            /opt/scripts/downcep_nomad8.sh $year $month $day
                #            er_ncep="$?"
		#	else
		#		echo "Hay proceso de descarga gfs completos"
		#	fi			
                #       if [ $er_ncep -ne 0 ];then
                #                echo "Descarga gfs completos salio con error"
                #        fi
                #fi
                logger "Directorio: $pathFiles"$year""$month""$day"-$hora/gfs" "INFO"
}

function validarGFS(){
        #error=0
        logger "######################################################################" "INFO"
        logger "############### Verificando tamaño de Ficheros GFS ###################" "INFO"
        logger "# $pathFiles/"$year""$month""$day"-$hora/gfs ####" "INFO"

        for i in `ls -ltrh $pathFiles/"$year""$month""$day"-$hora/gfs | awk '{print $9}'`;
        do
          file=$pathFiles"$year""$month""$day"-$hora/gfs/$i
	  echo "/nfs/users/working/installers/GRIB2/grib2/wgrib2 -s $file | wc -l"
          recFile=$(/nfs/users/working/installers/GRIB2/grib2/wgrib2 -s $file | wc -l )
         # Revisar gfs filtrados
         grep all_ $file
         if [ $? -eq 0 ];then
            logger "-------------- Verificando archivos all_ ------------------------" "INFO"
            recnum00=522
            recnumxx=588
            STRING="000.grb"
         else
            # Revisar gfs completos
            grep gfs_ $file
            if [ $? -eq 0 ];then
               logger "-------------- Verificando archivos gfs_ ------------------------" "INFO"
               recnum00=522
               recnumxx=588
               STRING="000"
            fi
         fi

         if [[ "$file" == *"$STRING" ]];then
            if [[ "$recFile" -lt "$recnum00" ]];then
                logger "El archivo: $file esta incompleto! :$recFile " "ERROR"
                rm $file
                error=1
                break
            else
                logger "El archivo: $file fue descargado completo!" "INFO"
            fi
         else
            if [[ "$recFile" -lt "$recnumxx" ]];then
                logger "El archivo: $file esta incompleto!: $recFile" "ERROR"
                rm $file
                error=1
                break
            else
                logger "El archivo: $file fue descargado completo!" "INFO"
            fi
         fi
        done

        numFiles=$(ls -1 $pathFiles/"$year""$month""$day"-$hora/gfs| wc -l)


        if [[ $numFiles -lt 25 ]];then
           error=1
           logger "Faltan archivos por descargar" "ERROR"
        fi
}

function runWRF(){
   logger "Ejecutando main py" "INFO"
   cd $BASE_PATH
   if ! test -d ./wrf_env ; then 
      logger "Creating virtual env wrf_env" "INFO"   
      sh ./create_env.sh 
   else 
      logger "Activating irtual env wrf_env" "INFO"  
      source ./wrf_env/bin/activate

   fi 
   cd $BASE_PATH
   logger "executing python3 ./scripts_op/main.py --start-date $rundate --run-time $1 --run-type cold" "INFO"
   ./scripts_op/main.py --start-date $rundate --run-time $1 --run-type cold 
   #source /etc/profile.d/cluster-vars.sh; python3.5 /wrf4/control/scripts_op/main.py --start-date $rundate --run-time $1 --run-type cold && python3.5 /wrf4/control/scripts_op/main.py --start-date $DATE --run-time $2 --run-type warm

}

function WRFLauncher(){
   #verificar si hay error, si no lo hay enviar la corrida
   DATE=`$datepath/date +%Y-%m-%d`
   DATE_plus=`$datepath/date +%Y-%m-%d --date=1days`
   logger $error "CONTROL"
   logger $hoursInt "CONTROL"
   error=0
   if pgrep -f "mainAntartida.py" &>/dev/null; then
      error=1
      logger "Error Aun Corriendo WRF Antartida " "ERROR"
   fi

   logger "Limpiando filesystem nfs /nfs/users" "INFO"
   #rm -rf /disco1/antartida/*
   #rm -rf /disco1/api/*
   logger "este es el error: $error" "INFO"
   if [[ $error == 0 ]];then
      if [[ $hoursInt -ge window00UTC[0] ]]  && [[ $hoursInt -le window00UTC[1] ]]; then
         if pgrep -f "main.py" &>/dev/null; then
            logger "it is already running 00Z" "INFO"
   #         exit
         else
            logger "correr main.py 00Z" "INFO" 
            runWRF "00" "09"
            exit
         fi
      elif [[ $hoursInt -ge window06UTC[0] ]]  && [[ $hoursInt -le window06UTC[1] ]]; then
         if pgrep -f "main.py" &>/dev/null; then
            logger "it is already running 06Z" "INFO"
   #          exit
         else
            logger "correr main.py 06Z" "INFO" 
            runWRF "06" "15"
            exit
         fi
      elif [[ $hoursInt -ge window12UTC[0] ]]  && [[ $hoursInt -le window12UTC[1] ]]; then
         if pgrep -f "main.py" &>/dev/null; then
            logger "it is already running 12Z" "INFO"
   #          exit
         else
            logger "correr main.py 12Z" "INFO" 
            runWRF "12" "21"
            exit
         fi
      elif [[ $hoursInt -ge window18UTC[0] ]]  && [[ $hoursInt -le window18UTC[1] ]]; then
         if pgrep -f "main.py" &>/dev/null; then
            logger "it is already running 18Z" "INFO"
   #          exit
         else
            logger "correr main.py 18Z" "INFO" 
            runWRF "18" "03"
            exit
         fi
      elif [[ $hoursInt -eq 0 ]];then
         if pgrep -f "main.py" &>/dev/null; then
            logger "it is already running 00Z" "INFO"
   #         exit
         else
            logger "correr main.py 00Z" "INFO" 
            runWRF "00" "09"
            exit
         fi
      else 
         echo "No correr modelo"
         logger "No correr modelo" "INFO"
         exit
      fi
   else
      echo "No correr modelo"
   fi
}

logger "Validating existence of $validateScript" "INFO"
pid=`ps aux | grep -v grep|grep -i $validateScript| awk '{print $2}'`
logger "PID: $pid" "INFO"
pid_count=${#pid[@]}
procesos=$((pid_count * 1))
logger "Number of processes: $procesos" "INFO" 
error=0
# Main Function
if [ -z "{$pid}" ] ; then
   logger "Failed to get the PID $pid" "ERROR"
fi

if [ -f "$BASE_PATH/automation/$validateScript.lock" ]; then
   logger "Lock file exists on $BASE_PATH/automation/$validateScript.lock" "INFO"

   if [[  $procesos -gt "2" ]]; then
      message="An another instance of this script is already running, please clear all the sessions of this script before starting a new session"
      logger "$message" "ERROR"
      exit 1
   else
      message="Looks like the last instance of this script exited unsuccessfully, perform cleanup, process continue"
      logger "$message" "ERROR"
      logger "Eliminando lock file" "INFO"
      rm -f "$BASE_PATH/automation/$script_name.lock"
     #
   fi
fi
echo $pid > $BASE_PATH/automation/$validateScript.lock
logger "Starting process of downloading GFS" "INFO"
downloadGFS
validarGFS
 
if [[ $error == 0 ]];then
     logger "Datos completos, verificando lanzamiento de WRF" "INFO"
     WRFLauncher
else
     echo "Descargando archivos completos"
     logger "Descargando archivos completos" "INFO"
     #/opt/scripts/downcep_nomad8.sh $year $month $day
fi

logger "Eliminando lock file" "INFO"
rm -f "$BASE_PATH/automation/$script_name.lock"
