#!/bin/bash

#!/bin/bash -x

#SBATCH --time=05:00:00
#SBATCH --export=ALL
#SBATCH --hint=multithread
#SBATCH --exclusive
#SBATCH --nodes=3
#SBATCH --ntasks=24            ## Number of tasks (analyses) to run
#SBATCH --ntasks-per-node=8


#SBATCH --job-name=obsproc-
#SBATCH --output=%x.%j.log
	



#module purge
# load intel compiler for C, C++, and FORTRAN
source /nfs/stor/intel/oneapi/setvars.sh 
source /nfs/users/working/corridas/WRF_env.sh
# load WRF_ENV
export RUN_PATH=/nfs/users/working/wrf4/corridas
#==========================================================
#source /nfs/users/working/wrf4/control/scripts_op/slurm/env_settings.sh
export BASE_DIR=$RUN_PATH/20240122-00
export LOGS_DIR=$BASE_DIR/logs
export RUNDIR=$BASE_DIR/wrfda/obsproc/
#mkdir -p $RUNDIR
cd $RUNDIR


export Data_Dir=$RUNDIR

ulimit -s unlimited
ulimit -n 10240
export TASK=24
export PPN=8
export NODES=3


### edit #####################

export OMP_NUM_THREADS=16
export OMP_STACKSIZE=32G
##############################

srun  srun --nodes=$NODES --ntasks=$TASK --ntasks-per-node=$PPN --mpi=pmi2  --cpus-per-task=$OMP_NUM_THREADS  --distribution=block:block,pack --cpu-bind=verbose  $Data_Dir/obsproc.exe 2>&1 | tee $LOGS_DIR/obsproc.log

