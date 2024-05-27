#!/bin/bash
#datepath=/bin
#year=`$datepath/date --utc +%Y`
#month=`$datepath/date --utc +%m`
#day=`$datepath/date --utc +%d`
#hours=`$datepath/date --utc +%H`
#gfsdir=/home/wrf/inidata/GFS/$year$month$day
datepath=/usr/bin
logdir=/tmp/

year=$1
mes=$2
day=$3

hours=`$datepath/date --utc +"%s"`
window00UTC=`$datepath/date --utc "-d $year-$mes-$day 03" +"%s"`
window06UTC=`$datepath/date --utc "-d $year-$mes-$day 09" +"%s"`
window12UTC=`$datepath/date --utc "-d $year-$mes-$day 15" +"%s"`
window18UTC=`$datepath/date --utc "-d $year-$mes-$day 21" +"%s"`

if [[ $hours -ge $window00UTC ]]  && [[ $hours -lt $window06UTC ]]; then
           hora=00
elif [[ $hours -ge $window06UTC ]]  && [[ $hours -lt $window12UTC ]]; then
           hora=06
elif [[ $hours -ge $window12UTC ]]  && [[ $hours -lt $window18UTC ]]; then
           hora=12
elif [[ $hours -ge $window18UTC ]] ; then
           hora=18
fi

#echo "[[ $hours -ge $window12UTC ]]  && [[ $hours -lt $window18UTC[1] ]]" 
echo 'hora' $hora

#Destino ejm. /wrf4/data/20200911-12/gfs
gfsdir=/wrf4/data/$year$mes$day-$hora/gfs/

#Fuentes:
#ncep='https://nomads.ncep.noaa.gov/pub/data/nccf/com/gfs/prod/'
ncepftp='ftp://ftp.ncep.noaa.gov/pub/data/nccf/com/gfs/prod/'
ncep='ftp://ftp.ncep.noaa.gov/pub/data/nccf/com/gfs/prod/'
dia=gfs.$year$mes$day"/"$hora""

#archivos 54 horas
for (( i = 0 ; i <= 72 ; i=i+3 )); do
  if [[ $i -lt 10 ]]; then
        list00[i]=gfs.t"$hora"z.pgrb2.0p25.f00"$i"
  else
        list00[i]=gfs.t"$hora"z.pgrb2.0p25.f0"$i"
  fi
done

#Borra los ultimos 31 dias
#for ((i=1;i<31;i++));do a=`$datepath/date "-d $year-$month-$day -$i day" +"%Y%m%d"`;rm -r /home/wrf/inidata/GFS/00Z/$a;done
mkdir -p $gfsdir

#Numero maximo de intentos por archivo
cyclenum=10
#maxrec00=352
#maxrecpr=415
maxrec00=522
maxrecpr=588

for i in ${list00[@]:0} ; do
    recnum=0
    numciclo=0

    ps -ef | grep -v grep | grep "wget -c -P $gfsdir $ncep/$dia/$i"
#1
	if [ $? -ne 0 ]; then
	   ps -ef | grep -v grep | grep "wget -c -P $gfsdir $ncepftp/$dia/$i"
#2
	     if [ $? -ne 0 ]; then
	       echo `date +"%Y-%m-%d %H:%M"` "DESCARGA URL: $ncep/$dia/$i"
#analisis:
	       if [ "$i" == "gfs.t"$hora"z.pgrb2.0p50.f000" ]; then
                  recnum=`/opt/grib2/wgrib2/wgrib2 -s $gfsdir/$i | wc -l`
                  if [ $recnum -ge $maxrec00 ]; then 
                     echo $i 'esta completo'
                     continue
                  fi

                  while [ $recnum -lt $maxrec00 ]; do                 
#ncep
                     wget -c -P $gfsdir  $ncep/$dia/$i
		     sleep 60
		     if [ $? -eq 0 ];then 
                         echo 'wget sale con exito!'
                         recnum=`/opt/grib2/wgrib2/wgrib2 -s $gfsdir/$i | wc -l`
                         if [ "$recnum" -ge $maxrec00 ];then
                              echo "El archivo GFS sirve: "recnum= "$recnum"
                              break
                         else
                              echo "NCEP: Archivo incompleto: "recnum= "$recnum"
#ncepftp
                              wget -c -P $gfsdir  $ncepftp/$dia/$i
                              sleep 60
		              if [ $? -eq 0 ];then 
                                  echo 'wget sale con exito!'
                                  recnum=`/opt/grib2/wgrib2/wgrib2 -s $gfsdir/$i | wc -l`
                                  if [ "$recnum" -ge $maxrec00 ];then
                                      echo "El archivo GFS sirve: "recnum= "$recnum"
                                      break
                                  else
                                      echo "NCEPFTP: Archivo incompleto: "recnum= "$recnum"
                                  fi
                              else
                                  echo 'NCEPFTP sin conexion'
                              fi
                         fi    
#NCEP wget!=0
                     else
                         echo 'NCEP sin conexion -> URL: $ncepftp'
		         wget -c -P $gfsdir $ncepftp/$dia/$i
                         sleep 60
                         if [ $? -eq 0 ];then 
                             echo 'wget sale con exito!'
                             recnum=`/opt/grib2/wgrib2/wgrib2 -s $gfsdir/$i | wc -l`
                             if [ "$recnum" -ge $maxrec00 ];then
                                 echo "El archivo GFS sirve: "recnum= "$recnum"
                                 break
                             else
                                 echo "Archivo incompleto en NCEPFTP: "recnum= "$recnum"
                             fi
                         else
#Aun no existe la hora o no hay conexion?
                             wget -O $logdir/index.html $ncepftp
                             
                             if [ $? -eq 0 ];then 
                                 echo `date +"%Y-%m-%d %H:%M"`': el archivo '$dia' aun no existe'; exit
                             else 
                                 echo `date +"%Y-%m-%d %H:%M"` 'SIN CONEXION A NOMADS'
                             fi
                         fi
                     fi
#10 intentos maximo por archivo 
                     if [ $numciclo -ge $cyclenum ];then
			echo 'descarga falla' 
			exit 1
			break
		     fi 
                     numciclo=$((numciclo+1))
                 done
	       else
#pronostico:
                 numciclo=0
                 recnum=`/opt/grib2/wgrib2/wgrib2 -s $gfsdir/$i | wc -l`
                 if [ $recnum -eq $maxrecpr ]; then echo $i 'esta completo';continue;fi

                 while [ $recnum -lt $maxrecpr ]; do                 
#ncep
                     wget -c -P $gfsdir  $ncep/$dia/$i
                     sleep 60
		     if [ $? -eq 0 ];then 
                         echo 'wget sale con exito!'
                         recnum=`/opt/grib2/wgrib2/wgrib2 -s $gfsdir/$i | wc -l`
                         if [ "$recnum" -ge $maxrecpr ];then
                              echo "El archivo GFS sirve: "recnum= "$recnum"
                              break
                         else
                              echo "NCEP: Archivo incompleto: "recnum= "$recnum"
#ncepftp
                              wget -c -P $gfsdir  $ncepftp/$dia/$i
                              sleep 60
		              if [ $? -eq 0 ];then 
                                  echo 'wget sale con exito!'
                                  recnum=`/opt/grib2/wgrib2/wgrib2 -s $gfsdir/$i | wc -l`
                                  if [ "$recnum" -ge $maxrec00 ];then
                                      echo "El archivo GFS sirve: "recnum= "$recnum"
                                      break
                                  else
                                      echo "NCEPFTP: Archivo incompleto: "recnum= "$recnum"
                                  fi
                              else
                                  echo 'NCEPFTP sin conexion'
                              fi
                         fi
#NCEP wget!=0
                     else
                         echo 'NCEP sin conexion URL: $ncepftp'
		         wget -c -P $gfsdir $ncepftp/$dia/$i
                         sleep 60
                         if [ $? -eq 0 ];then 
                             echo 'wget sale con exito!'
                             recnum=`/opt/grib2/wgrib2/wgrib2 -s $gfsdir/$i | wc -l`
                             if [ "$recnum" -ge $maxrecpr ];then
                                 echo "El archivo GFS sirve: "recnum= "$recnum"
                                 break
                             else
                                 "NCEPFTP: Archivo incompleto: "recnum= "$recnum"
                             fi
                         else
#Aun no existe la hora o no hay conexion?
                             wget -O $logdir/index.html $ncepftp
        
                             if [ $? -eq 0 ];then 
                                 echo `date +"%Y-%m-%d %H:%M"` 'el archivo '$dia' aun no existe'; exit
                             else 
                                 echo `date +"%Y-%m-%d %H:%M"` 'SIN CONEXION A NOMADS'
                             fi
                         fi
                     fi
#10 intentos maximo por archivo 
                     if [ $numciclo -ge $cyclenum ];then
			echo 'descarga falla' 
			exit 1
			break
		     fi 
                     numciclo=$((numciclo+1))
                 done
               fi
#2
             fi
#1
	fi
done
