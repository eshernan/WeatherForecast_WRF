
#!/bin/bash
#################################################################
# Script for compiling WRF libraries for Intel oneAPI compilers
#################################################################
source ../../setup_env.sh 

#################################################################
# Load the Intel OneAPI Compilers environment
#################################################################
source ~/intel/oneapi/setvars.sh

#for Intel Cluster Compilers
export CC=icx
export FC=ifx
export CXX=icx

cd $INSTALLERS
echo "-------------------------------------------------"
echo "----------- Compiling ZLIB  ---------------------"
echo "-------------------------------------------------"

cd zlib-$ZLIB
./configure --prefix=$LIBS/compiled
make
make install
cd ..
echo "-------------------------------------------------"
echo "----------- Compiling  LIBPNG  ------------------"
echo "-------------------------------------------------"

cd libpng-$LIBPNG
./configure --prefix=$LIBS/compiled #--build=arm
make
make install
cd ..
echo "-------------------------------------------------"
echo "----------- Compiling JASPER  -------------------"
echo "-------------------------------------------------"

cd jasper
./configure --prefix=$LIBS/compiled
make
make install
cd ..
# cd mpich*
# ./configure --prefix=$SHARED/libs/mpich --with-slurm=/usr/lib64/slurm --enable-shared
# make
# make install
# cd ..
# export  LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$SHARED/libs/mpich/lib
# export PATH=$PATH:$SHARED/libs/mpich/bin
export CC=mpiicc
export FC=mpiifort
export CXX=mpiicpc
#export CFLAGS='-O3 -xHost -ip -no-prec-div -static-intel'
#export CXXFLAGS='-O3 -xHost -ip -no-prec-div -static-intel'
#export FFLAGS='-O3 -xHost -ip -no-prec-div -static-intel'
# export CXXFLAGS=-03

echo "-------------------------------------------------"
echo "----------- Compiling HDF5  ---------------------"
echo "-------------------------------------------------"

 cd hdf5
./configure --prefix=$LIBS/compiled --enable-parallel --enable-fortran  --enable-optimization=high --with-default-api-version=v18
make
make install
cd ..
echo "-------------------------------------------------"
echo "----------- Compiling PNETCDF  ------------------"
echo "-------------------------------------------------"

cd pnetcdf
CPPFLAGS="-I$LIBS/compiled/include/" LDFLAGS=-L$LIBS/compiled/lib/ ./configure --prefix=$LIBS/compiled  --enable-shared --enable-static
make
make install
cd ..
echo "-------------------------------------------------"
echo "----------- Compiling NETCDF-C  -----------------"
echo "-------------------------------------------------"
cd netcdf-c
CPPFLAGS="-I$LIBS/compiled/include/ -I$LIBS/compiled/include" LDFLAGS="-L$LIBS/compiled/lib/ -L$LIBS/compiled/lib" ./configure --prefix=$LIBS/compiled --enable-netcdf-4 --enable-pnetcdf -enable-shared
make
make install
cd ..

echo "-------------------------------------------------"
echo "----------- Compiling NETCDF-FORTRAN  -----------"
echo "-------------------------------------------------"

cd netcdf-fortran
LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$LIBS/compiled/lib CPPFLAGS="-I$LIBS/compiled/include/ -I$LIBS/compiled/include" LDFLAGS="-L$LIBS/compiled/lib/ -L$LIBS/compiled/lib" ./configure --prefix=$LIBS/compiled --enable-shared 
make
make install
cd ..
# cd papi
# ./configure --prefix=$SHARED/libs/papi
# make
# make install
# cd ..
export NETCDF=$LIBS/compiled
export HDF5=$LIBS/compiled
export PHDF5=$LIBS/compiled
export JASPERLIB=$LIBS/compiled/lib
export JASPERINC=$LIBS/compiled/include
export PATH=$PATH:$LIBS/compiled/bin