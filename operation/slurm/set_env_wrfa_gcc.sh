#!/bin/bash
#Validating that setvar already was invoked to avoid errors
unset LD_LIBRARY_PATH
source /nfs/stor/intel/oneapi/mpi/2021.11/env/vars.sh


export MAIN_DIR=/nfs/users/working/installers/SHARED/gcc
export NETCDF=$MAIN_DIR/libs
#export PNETCDF=$MAIN_DIR/libs/lib
#export JASPERINC=$MAIN_DIR/libs/include
#export JASPERLIB=$MAIN_DIR/libs/lib
export HDF5=$MAIN_DIR/libs
#export PHDF5=$MAIN_DIR/libs
#export ZLIB=$MAIN_DIR/libs
export WRFIO_NCD_LARGE_FILE_SUPPORT=1
#validating that LD_LIBRARY_PATH already setup 
echo "Validating that LD_LIBRARY_PATH already setup "
echo "WRFGCCSETUP_COMPLETE is $WRFGCCSETUP_COMPLETE"
if test -z "$WRFGCCSETUP_COMPLETE" 
  then 
	  export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$MAIN_DIR/libs/lib
	  echo "new value for LD_LIBRARY_PATH is $LD_LIBRARY_PATH"
  else
	  echo "LD_LIBRARY_PATH already setup"
fi
export WRFGCCSETUP_COMPLETE=1
ulimit -s unlimited
ulimit -n 10240
