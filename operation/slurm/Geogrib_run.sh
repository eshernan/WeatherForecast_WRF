#!/bin/bash -x

#SBATCH --time=05:00:00
#SBATCH --export=ALL
#SBATCH --hint=multithread
#SBATCH --exclusive
#SBATCH --nodes=3
#SBATCH --ntasks=24             ## Number of tasks (analyses) to run
#SBATCH --ntasks-per-node=8

#SBATCH --job-name=WPS-4.5.3


#module purge
# load intel compiler for C, C++, and FORTRAN
source /nfs/users/working/corridas/WRF_env.sh
#Load Simulation Date from Environment 
#source /nfs/users/working/wrf4/control/scripts_op/slurm/env_settings.sh
# load WRF_ENV
export RUN_PATH=/nfs/users/working/wrf4/corridas
#==========================================================

export RUNDIR=$RUN_PATH/20240122-00/wps
#mkdir -p $RUNDIR
cd $RUNDIR


ulimit -s unlimited
ulimit -n 10240

### edit #####################

export np=24
export ppn=8
export OMP_NUM_THREADS=16
export OMP_STACKSIZE=32G
##############################
#export LD_PRELOAD=/nfs/stor/intel/oneapi/itac/latest/slib/libVT.so
#export VT_LOGFILE_NAME=WRF-trace-MPI.stf
#export VT_LOGFILE_FORMAT=SINGLESTF
#export VT_PCTRACE=5


srun  --mpi=pmi2 --distribution=block:block,pack --cpu-bind=verbose  geogrid.exe 2>&1 | tee ${RUNDIR}/logs/geogrib.out${SLURM_JOBID}

