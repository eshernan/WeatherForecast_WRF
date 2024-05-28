!/bin/bash
# Esteban Hernandez, 
# This script downloads the required libraries for compiling WRF and WPS

#INSTALLER_PATH is the base where each lib will be downloaded, uncompressed and compiled

cd $INSTALLER_PATH

source ./setup_env.sh 

wget https://downloads.unidata.ucar.edu/netcdf-c/$NETCDF_C/netcdf-c-$NETCDF_C.tar.gz 
wget https://downloads.unidata.ucar.edu/netcdf-fortran/$NETCDF_FORTRAN/netcdf-fortran-$NETCDF_FORTRAN.tar.gz 
wget https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-${HDF5:0:-2}/hdf5-$HDF5/src/hdf5-$HDF5.tar.gz 
wget https://parallel-netcdf.github.io/Release/pnetcdf-$PNETCDF.tar.gz
wget --no-check-certificate https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/jasper-$JASPER.tar.gz 
wget --no-check-certificate https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/libpng-$LIBPNG.tar.gz 
wget --no-check-certificate https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/zlib-$ZLIB.tar.gz 
# #wget --no-check-certificate https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/mpich-3.0.4.tar.gz -O mpich.tar.gz
# #git clone https://bitbucket.org/icl/papi.git


tar -zxvf netcdf-c-$NETCDF_C.tar.gz 
tar -zxvf netcdf-fortran-$NETCDF_FORTRAN.tar.gz
tar -zxvf hdf5-$HDF5.tar.gz 
tar -zxvf jasper-$JASPER.tar.gz &&
tar -zxvf libpng-$LIBPNG.tar.gz 
tar -zxvf zlib-$LIBPNG.tar.gz 
tar -zxvf pnetcdf-$PNETCDF.tar.gz
# #tar -zxvf mpich-3.0.4.tar.gz
echo " .... required libs download sucessful ...."
cd $SHARED
git clone https://github.com/wrf-model/WPS.git
git clone https://github.com/wrf-model/WRF.git
echo " .... WRF and WPS cloned sucessful ...."
mkdir GEO_STATIC_DATA
cd GEO_STATIC_DATA
export GEO_STATIC_DATA=$PWD
wget --no-check-certificate  https://www2.mmm.ucar.edu/wrf/src/wps_files/geog_high_res_mandatory.tar.gz
tar -zxvf geog_high_res_mandatory.tar.gz

# cd ..