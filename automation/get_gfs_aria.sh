#!/bin/bash
# Chris Reudenbach
# Version: 0.1 date: 2015-06-17
#          0.2 date: 2015-06-20
#                    add commandline and nettiquette
#                    add default settings
#          0.3 date: 2015-06-21 added path and conversion arguments
# simple script to download (selected) GFS 0.25 data for a forecast period
# from the NCEP NOAA archive
# Additionally it converts the single files to one datafile for use with IDV etc.
# and comfortable timeseries analysis
# generates netcdf, grib1 and grib2 all in one files
# instad of setting the working folders by command line arguments
# you may change them in the script
# note the structure ist $HOME/$DATADIR/$MODELDIR

datepath=/usr/bin
year=`$datepath/date --utc +%Y`
month=`$datepath/date --utc +%m`
day=`$datepath/date --utc +%d`
hours=`$datepath/date --utc +%H`
minute=`$datepath/date --utc +%M`
###############################################################
# This variables should used on all path for install or use of 
###############################################################
BASE_PATH=/nfs/users/working/wrf4/control
DATA_PATH=/nfs/users/working/wrf4/data
##############################################################

function logger(){
message="$1"
status="$2"
printf "$year$month$day$hours$minute ${status}: ${message}\n"

}


if [[ "$1" == '-h' ]]; then
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ "
    echo " <getGribGFS.sh> downloads the 0.25° GFS GRIB2 date"
    echo " By default you will get the whole world data set by 10 days "
    echo " It is strongly recommended to extract a ROI"
    echo " "
    echo "Usage: ./getGribGFS.sh -h gives this brief help "
    echo "       ./getGribGFS.sh -d=YYYYMMDD -r=00 -wl=DDD.DD -el=DDD.DD -nl=DDD.DD -sl=DDD.DD -st=0 -et=96 -nc=FALSE -g1=FALSE -f1=DataDir -f2=MTypDir -f3=<pathtoscript>"
    echo""
    echo " -d=YYYYMMDD  :  date i.e. 20150621"
    echo " -r=HH        :  hour of run [00 06 12 18]"
    echo " -wl=DDD.DD   :  western  Longitude of area to extract"
    echo " -el=DDD.DD   :  eastern  Longitude of area to extract"
    echo " -sl=DDD.DD   :  southern Latitude of area to extract"
    echo " -nl=DDD.DD   :  northern Latitude of area to extract"
    echo "                 all in decimal degrees"
    echo "                 default lon [0 360], lat [-90 90]"
    echo " -st=HH       :  start time [0] of forecast"
    echo " -et=HH       :  end time [96]  of forecast"
    echo "                 0.25 GFS 3h => 96=10 days "
    echo " -nc=boolean  :  <[FALSE]/TRUE> convert data to netcdf format"
    echo " -g1=boolean  :  <[FALSE]/TRUE> convert data to grib1 format"
    echo " -f1=DATADIR  :  <[wxdata]> root data directory under $HOME"
    echo " -f2=MTypDir  :  <[GFS25]> convert data to grib1 format"
    echo " -f3=ScriptDir:  <[[scripting]> script folder under $HOME/dev "
    echo " "
    echo " example      :  ./getGribGFS.sh -d=20150620 -r=00 -wl=-10.5 -el=20.25 -nl=60.75 -sl=40.0"
    exit 0
fi

for i in "$@"
do
case $i in
    -d=*|--date=*)
    date="${i#*=}"
    ;;
    -r=*|--date=*)
    run="${i#*=}"
    ;;
    -wl=*)
    leftlon="${i#*=}"
    ;;
    -el=*)
    rightlon="${i#*=}"
    ;;
    -nl=*)
    toplat="${i#*=}"
    ;;
    -sl=*)
    bottomlat="${i#*=}"
    ;;
    -st=*)
    StartTime="${i#*=}"
    ;;
    -et=*)
    EndTime="${i#*=}"
    ;;
    -nc=*)
    netCDF="${i#*=}"
    ;;
    -g1=*)
    grib1="${i#*=}"
    ;;
    -f1=*)
    DATADIR="${i#*=}"
    ;;
    -f2=*)
    MODELDIR="${i#*=}"
    ;;
    -f3=*|--type=*)
    SCRIPTDIR="${i#*=}"
    ;;
    --default)
    DEFAULT=YES
    ;;
    *)
            # unknown option
    ;;
esac
done

######
# identify users home
USER=`whoami`
# define default variables
if [[ "${date}" == "" ]]      ; then  param=FALSE; date=`date -u +%Y%m%d`; fi
if [[ "${run}" == "" ]] && [[ "${run}" != "00" ]] && [[ "${run}" && "06" ]] && [[ "${run}" != "12" ]] && [[ "${run}" != "18" ]]  ; then  param=FALSE; run="00"; fi
if [[ "${StartTime}" == "" ]] ; then  param=FALSE; StartTime=0 ; fi
if [[ "${EndTime}" == ""   ]] ; then  param=FALSE; EndTime=96 ; fi
if [[ "${leftlon}" == ""   ]] ; then  param=FALSE; leftlon="0" ; fi
if [[ "${rightlon}" == ""  ]] ; then  param=FALSE; rightlon="360" ; fi
if [[ "${toplat}" == ""    ]] ; then  param=FALSE; toplat="90" ; fi
if [[ "${bottomlat}" == "" ]] ; then  param=FALSE; bottomlat="-90" ; fi
if [[ "${netCDF}" == ""    ]] ; then  param=FALSE; netCDF="FALSE" ; fi
if [[ "${grib1}" == "" ]]     ; then  param=FALSE; grib1="FALSE" ; fi
if [[ "${DATADIR}" == "" ]]   ; then  param=FALSE; DATADIR="wxdata" ; fi
if [[ "${MODELDIR}" == "" ]]  ; then  param=FALSE; MODELDIR="GFS25" ; fi
if [[ "${SCRIPTDIR}" == "" ]] ; then param=FALSE;  SCRIPTDIR="automation";  fi
if [[ "${param}" == "FALSE" ]]; then
logger "one ore more arguments omitted..." "INFO"
logger "get help with ./getGFS.sh -h" "INFO"
logger "Nevertheless proceeding with DEFAULT values..." "INFO" ;
fi
logger "argument list:" "INFO"
logger "date=${date}" "INFO"
logger "run=${run}" "INFO"
logger "StartTime=${StartTime}" "INFO"
logger "EndTime=${EndTime}" "INFO"
logger "leftlon=${leftlon}" "INFO"
logger "rightlon=${rightlon}" "INFO"
logger "toplat=${toplat}" "INFO"
logger "bottomlat=${bottomlat}" "INFO"
logger "netCDF=${netCDF}" "INFO"
logger "grib1=${grib1}" "INFO"
logger "DATADIR=${DATADIR}" "INFO"
logger "MODELDIR=${MODELDIR}" "INFO"


SCRIPTPATH=$BASE_PATH/${SCRIPTDIR}
logger "SCRIPTPATH = ${SCRIPTPATH}" "INFO"
# set datapath (currently GFS25)
filename=$(basename "$INFILE")
filename="${filename%.*}"
fndate=${filename:20:8}
INDATAPATH=$(dirname "$INFILE")
EXDATAPATH=$DATA_PATH/$DATADIR/gfs/

logger "~~~~~~~~~~~~~~~~~" "INFO"
logger "output folder:" "INFO"
logger "$EXDATAPATH" "INFO"
logger "~~~~~~~~~~~~~~~~~" "INFO"


# create directories
if [ ! -d $EXDATAPATH ]; then mkdir -p ${EXDATAPATH} ; fi

# change directory to runtime directory
cd $EXDATAPATH

# fix the substitution variables to fixed format 3 numbers
charNewHour=$(printf "%03d\n" $StartTime)
charStartTime=$(printf "%02d\n" $StartTime)
hour=$StartTime

# here we put the filter URL of the noaa g2sub service (i.e. http://nomads.ncep.noaa.gov/cgi-bin/filter_gfs_0p25.pl?dir=%2Fgfs.2015061700)
# we can also use the regular download from gribmaster  or similar scripts
# next line you will find a filter call currently we are loading all levels and all vars in a small subregion.
# be careful each full earth all variables&levels file is about 550 MB and GRIB is a really good compression!
#URL="http://nomads.ncep.noaa.gov/cgi-bin/filter_gfs_0p25.pl?file=gfs.t${run}z.pgrb2.0p25.f${charNewHour}&lev_1000_mb=on&lev_100_mb=on&lev_10_m_above_ground=on&lev_200_mb=on&lev_2_m_above_ground=on&lev_300_mb=on&lev_400_mb=on&lev_500_mb=on&lev_600_mb=on&lev_700_mb=on&lev_750_mb=on&lev_800_mb=on&lev_850_mb=on&lev_900_mb=on&lev_925_mb=on&lev_950_mb=on&lev_975_mb=on&var_4LFTX=on&var_ALBDO=on&var_CAPE=on&var_CIN=on&var_CLWMR=on&var_CPRAT=on&var_CRAIN=on&var_CSNOW=on&var_CWAT=on&var_CWORK=on&var_DPT=on&var_GUST=on&var_HGT=on&var_POT=on&var_PRATE=on&var_PRES=on&var_RH=on&var_SUNSD=on&var_TMAX=on&var_TMIN=on&var_TMP=on&var_UGRD=on&var_VGRD=on&var_VVEL=on&subregion=&leftlon=${leftlon}&rightlon=${rightlon}&toplat=${toplat}&bottomlat=${bottomlat}&dir=%2Fgfs.${date}${run}"
# allvars and all levels in a subregion

# initial setup the url

URL="https://nomads.ncep.noaa.gov/cgi-bin/filter_gfs_0p25.pl?file=gfs.t${run}z.pgrb2.0p25.f${charNewHour}&all_lev=on&all_var=on&subregion=&leftlon=${leftlon}&rightlon=${rightlon}&toplat=${toplat}&bottomlat=${bottomlat}&dir=%2Fgfs.${date}%2F${run}%2Fatmos"
echo $URL

#URL="https://nomads.ncep.noaa.gov/cgi-bin/filter_gfs_0p50.pl?file=gfs.t${run}z.pgrb2full.0p50.f${charNewHour}&all_lev=on&all_var=on&subregion=&leftlon=${leftlon}&rightlon=${rightlon}&toplat=${toplat}&bottomlat=${bottomlat}&dir=%2Fgfs.${date}%2F${run}"

# first we check if the file exist
cd /
logger "check if data is available...." "INFO using "
COMMAND=`curl --head $URL 2>&1 | grep -E 'HTTP/.+200*'`
echo "Command to execute $COMMAND" 
if [[ $COMMAND ]]
 then
    logger "------------START DOWNLOAD--------------" "INFO"
    logger "${EXDATAPATH}all_${date}${run}_f000.grb"
    if [ ! -f ${EXDATAPATH}all_${date}${run}_f000.grb ]; then
       #logger "descargar: aria2c $URL -o ${EXDATAPATH}all_${date}${run}_f000.grb"
       aria2c --connect-timeout=5 "$URL" -o ${EXDATAPATH}all_${date}${run}_f000.grb
   # else
       #logger "ya existe: aria2c $URL -o ${EXDATAPATH}all_${date}${run}_f000.grb"
    #   aria2c "$URL" -o ${EXDATAPATH}all_${date}${run}_f000.grb
    fi
	file_size_00=`du -k "${EXDATAPATH}all_${date}${run}_f000.grb" | cut -f1`
	# start loop over all time slots NOTE GFS 0.25 has a 3 hours cycle
	while [ $hour -le $EndTime ]
	do
		# loop setup the url
            URL="https://nomads.ncep.noaa.gov/cgi-bin/filter_gfs_0p25.pl?file=gfs.t${run}z.pgrb2.0p25.f${charNewHour}&all_lev=on&all_var=on&subregion=&leftlon=${leftlon}&rightlon=${rightlon}&toplat=${toplat}&bottomlat=${bottomlat}&dir=%2Fgfs.${date}%2F${run}%2Fatmos"

            if [ ! -f ${EXDATAPATH}all_${date}${run}_f${charNewHour}.grb ]; then
	       logger "-----------------------------------------------" "INFO"
               logger "Descargando file:  ${EXDATAPATH}all_${date}${run}_f${charNewHour}.grb" "INFO"
               logger "de: $URL" "INFO"
               aria2c --connect-timeout=5 "$URL" -o ${EXDATAPATH}all_${date}${run}_f${charNewHour}.grb 
	       logger "-----------------------------------------------" "INFO"
             else
		  file_size_run=`du -k "${EXDATAPATH}all_${date}${run}_f${charNewHour}.grb" | cut -f1`
          comp=$(echo "$file_size_00" | awk '{printf("%d\n",$file_size_00 * 0.2 +$file_size_00)}')
		  if (( $file_size_run < $file_size_00 )) ; then
	 	     logger "HALLO" "INFO"
    		     # then we get the data via cURL
	             logger "-----------------------------------------------" "INFO"
                     logger "Descargando file:  ${EXDATAPATH}all_${date}${run}_f${charNewHour}.grb" "INFO"
		     logger "de: $URL " "INFO"
	    	     aria2c --connect-timeout=5 "$URL" -o ${EXDATAPATH}all_${date}${run}_f${charNewHour}.grb
	             logger "-----------------------------------------------" "INFO"
                     logger "$file_size_run > $comp " "INFO"
          #         elif (( $file_size_run > comp)) ; then
         #            curl "$URL" -o all_${date}${run}_f${charNewHour}.grb

		  fi
   	      fi
		# INCREMENT timeslot
		hour=$(($hour + 3))
		# correct time format for substitution
        charNewHour=$(printf "%03d\n" $hour)
	done
else
	logger "-----------------------------------------------" "INFO"
	logger "Currently the requested Data is NOT available." "INFO"
	logger "Please check the date of the request. " "INFO"
	logger "Note: GFS 0.25 files have about a 7 hours delay." "INFO"
	exit
fi


# rename initial analysis data due to a different number of variables
#mv gfs.t${run}z.pgrb2.0p25.f000 gfs.t${run}z.pgrb2.0p25.f000.grb

# merge all grib2 files to one
#cdo -O mergetime gfs.t${run}z.pgrb2.0p25.f??? gfs.t${run}z.pgrb2.0p25.${date}_${charStartTime}_${EndTime}.grb

# grib2 to netcdf
#if [[ "${netCDF1}" == "TRUE" ]] ; then
  # convert it to netcdf (it seems to work even if there some warnings)
#  cdo -f nc copy gfs.t${run}z.pgrb2.0p25.${date}_${charStartTime}_${EndTime}.grb gfs.t${run}z.pgrb2.0p25.${date}_${charStartTime}_${EndTime}.nc
  # and squeeze it via shuffeling and compressing (http://www.unidata.ucar.edu/blogs/developer/en/entry/netcdf_compression)
#  nccopy -u -d5 gfs.t${run}z.pgrb2.0p25.${date}_${charStartTime}_${EndTime}.nc gfs.t${run}z.0p25.${date}_${charStartTime}_${EndTime}.nc
  # remove uncompressed file
#  if [ ! -f gfs.t${run}z.pgrb2.0p25.${date}_${charStartTime}_${EndTime}.nc ]; then rm -r gfs.t${run}z.pgrb2.0p25.${date}_${charStartTime}_${EndTime}.nc ; fi
#fi
#echo $(printf %.$2f $(echo "scale=0;(((10^$file_size_00)*$1)+0.5)/(10^$file_size_00)" | bc))
# grib2 to grib1
#if [[ "${grib1}" == "TRUE" ]] ; then
  # convert the grib 2 to grib one for usage with zygrib
#  cnvgrib -g21 ${date}/gfs.t${run}z.pgrb2.0p25.${date}_${charStartTime}_${EndTime}.grb ${date}/gfs.t${run}z.pgrb1.0p25.${date}_${charStartTime}_${EndTime}.grb
#fi

# remove single files
#rm -r gfs.t${run}z.pgrb2.0p25.f???

logger "getGFS_aria.sh finished" "INFO"
