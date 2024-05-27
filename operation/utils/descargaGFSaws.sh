#!/bin/bash
 
#########################################
# LICENSE
#Copyright (C) 2012 Dr. Marcial Garbanzo Salas
#This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
#This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.
#########################################
 
#########################################
# AUTHOR
# This program was created at the University of Costa Rica (UCR)
# It is intended as a tool for meteorology students to obtain data from GOES16
# but it can be used by operational and research meteorology.
#########################################
 
#########################################
# Warning: This program can download a LARGE amount of information
# and this can cause problems with limited bandwidth networks or
# computers with low storage capabilities.
#########################################
 
#########################################
# CLEANING FROM PREVIOUS RUNS
#
#rm DesiredDataRADAR.txt
#rm FullListRADAR.txt
#########################################
 
echo "GFS data downloader"
#########################################
# CONFIGURATION
#
# YEAR OF INTEREST
YEAR=$1

# DAYS OF THE YEAR
# Can use this link to find out: https://www.esrl.noaa.gov/gmd/grad/neubrew/Calendar.jsp
# Example: 275 for October 2nd, 2017
# NOTE: There is only about 60 days previous to the current date available
DAY=$3
MONTH=$2
HOUR=$4

#########################################
# Get list of remote files available
# PART 1. Obtain full list of files
#


aws s3 --no-sign-request ls --recursive s3://noaa-gfs-bdp-pds/gfs.$YEAR$MONTH$DAY/$HOUR/atmos/ | awk '{print $3";"$4}' > FullListGFS.txt
 

#
# PART 2. Select only desired channels
#last_hour=$(($HOUR - 01))
#last_hour="$(printf "%02d" $last_hour)"
#test="${YEAR:2:3}${MONTH}${DAY}${last_hour}4" 
#test1="${YEAR:2:3}${MONTH}${DAY}${HOUR}0" 
#test2="${YEAR:2:3}${MONTH}${DAY}${HOUR}1" 
grep "gfs.t${HOUR}z.pgrb2.0p25.f" FullListGFS.txt > DesiredDataGFS.txt
awk '!/idx/' DesiredDataGFS.txt > DesiredDataGFS2.txt
#head -25 DesiredDataGFS2.txt > DesiredDataGFS.txt

input_file="DesiredDataGFS2.txt"
output_file="DesiredDataGFS3.txt"

# Asegurarse de que el archivo de salida esté vacío
> "$output_file"

# Leer cada línea del archivo de entrada
while IFS= read -r line
do
  # Extraer el número de pronóstico de la ruta del archivo
  forecast_number=$(echo "$line" | grep -oP 'f\K\d+')
  # Interpretar el número de pronóstico explícitamente como base 10
  forecast_number=$((10#$forecast_number))

  # Comprobar si el número de pronóstico es exactamente múltiplo de 3, incluyendo 000
  if (( forecast_number % 3 == 0 )); then
    # Escribir la línea en el archivo de salida si es múltiplo de 3
    echo "$line" >> "$output_file"
  fi
done < "$input_file"


head -25 DesiredDataGFS3.txt > DesiredDataGFS.txt
echo "seleccionterminada"


output="/nfs/users/working/wrf4/data/$YEAR$MONTH$DAY-$HOUR/gfs"
mkdir -p $output

#########################################
 
#########################################
# DOWNLOAD
#
 
for x in $(cat DesiredDataGFS.txt);
do
echo $x
SIZE=$(echo $x | cut -d";" -f1)
FULLNAME=$(echo $x | cut -d";" -f2)
NAME=$(echo $x | cut -d"/" -f5)
 
echo "Processing file $NAME of size $SIZE"
if [ -f $NAME ]; then
 echo "This file exists locally"
 LOCALSIZE=$(du -sb $NAME | awk '{ print $1 }')
 if [ $LOCALSIZE -ne $SIZE ]; then
 echo "The size of the file is not the same as the remote file. Downloading again..."
 aws s3 --no-sign-request cp s3://noaa-gfs-bdp-pds/$FULLNAME $output 
 else
 echo "The size of the file matches the remote file. Not downloading it again."
 fi
else
 echo "This file does not exists locally, downloading..."
 aws s3 --no-sign-request cp s3://noaa-gfs-bpd-pds/$FULLNAME $output
fi
 
done
#########################################

echo "Cambiando nombre a los archivos descargados" 
cd $output

# Iterar sobre cada archivo en la carpeta
for archivo in *; do
    # Extraer el número de pronóstico del nombre del archivo
    numero_pronostico=$(echo "$archivo" | grep -oP 'f\K\d+')

    # Crear el nuevo nombre de archivo
    nuevo_nombre="all_${YEAR}${MONTH}${DAY}${HOUR}_f${numero_pronostico}.grb"

    # Renombrar el archivo
    mv "$archivo" "$nuevo_nombre"
done
echo Program ending.
