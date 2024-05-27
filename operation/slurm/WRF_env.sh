#!/bin/bash
#Validating that setvar already was invoked to avoid errors
if  test -z "$SETVARS_COMPLETED"
  then
    source /nfs/stor/intel/oneapi/setvars.sh
else
    echo "Already setvars from oneAPI path invoked "
fi

export MAIN_DIR=/nfs/users/working/installers/sam/WRF_AF
export NETCDF=$MAIN_DIR/Libs_Intel/Install
export PNETCDF=$MAIN_DIR/Libs_Intel/Install
export JASPERINC=$MAIN_DIR/Libs_Intel/Install/include
export JASPERLIB=$MAIN_DIR/Libs_Intel/Install/lib
export HDF5=$MAIN_DIR/Libs_Intel/Install
export PHDF5=$MAIN_DIR/Libs_Intel/Install
export ZLIB=$MAIN_DIR/Libs_Intel/Install
export WRFIO_NCD_LARGE_FILE_SUPPORT=1
#validating that LD_LIBRARY_PATH already setup 
if test -z "$WRFSETUP_COMPLETE" 
  then 
	  export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$MAIN_DIR/Libs_Intel/Install/lib
	  echo "new value for LD_LIBRARY_PATH is $LD_LIBRARY_PATH"
  else
	  echo "LD_LIBRARY_PATH already setup"
fi
export WRFSETUP_COMPLETE=1
ulimit -s unlimited
ulimit -n 10240
