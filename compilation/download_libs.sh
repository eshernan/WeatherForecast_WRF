!/bin/bash
# Esteban Hernandez, 
# This script downloads the required libraries for compiling WRF and WPS

#INSTALLER_PATH is the base where each lib will be downloaded, uncompressed and compiled
INSTALLER_PATH='/home/eshernand/wrf/installers'


cd $INSTALLER_PATH
# NetCDF current version is 4.6.1
wget https://downloads.unidata.ucar.edu/netcdf-fortran/4.6.1/netcdf-fortran-4.6.1.tar.gz -O netcdf-fortran.tar.gz
# NetCDF current version is 4.9.2
wget https://downloads.unidata.ucar.edu/netcdf-c/4.9.2/netcdf-c-4.9.2.tar.gz -O netcdf-c.tar.gz
# Parallel netcdf current version is 1.13.0
wget https://parallel-netcdf.github.io/Release/pnetcdf-1.13.0.tar.gz -O pnetcdf.tar.gz


# HDF5 current version is 1.14.3
wget https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-1.14/hdf5-1.14.3/src/hdf5-1.14.3.tar.gz -O hdf5.tar.gz


wget --no-check-certificate https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/jasper-1.900.1.tar.gz -O jasper.tar.gz
wget --no-check-certificate https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/libpng-1.2.50.tar.gz -O libpng.tar.gz
wget --no-check-certificate https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/zlib-1.2.11.tar.gz -O   zlib.tar.gz
#wget --no-check-certificate https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/mpich-3.0.4.tar.gz -O mpich.tar.gz
#git clone https://bitbucket.org/icl/papi.git


tar -zxvf netcdf-c.tar.gz
tar -zxvf netcdf-fortran.tar.gz
tar -zxvf hdf5.tar.gz
tar -zxvf jasper.tar.gz
tar -zxvf libpng.tar.gz
tar -zxvf zlib.tar.gz
tar -zxvf pnetcdf.tar.gz
#tar -zxvf mpich-3.0.4.tar.gz
echo " .... required libs download sucessful ...."
cd $SHARED
git clone https://github.com/wrf-model/WPS.git
git clone https://github.com/wrf-model/WRF.git
echo " .... WRF and WPS download sucessful ...."
mkdir GEO_STATIC_DATA
cd GEO_STATIC_DATA
export GEO_STATIC_DATA=$PWD
wget --no-check-certificate  https://www2.mmm.ucar.edu/wrf/src/wps_files/geog_high_res_mandatory.tar.gz

tar -zxvf geog_high_res_mandatory.tar.gz
cd ..