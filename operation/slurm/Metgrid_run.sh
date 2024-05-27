#!/bin/bash -x

#SBATCH --time=05:00:00
#SBATCH --export=ALL
#SBATCH --hint=multithread
#SBATCH --exclusive
#SBATCH --nodes=3
#SBATCH --ntasks=384            ## Number of tasks (analyses) to run
#SBATCH --ntasks-per-node=128

#SBATCH --job-name=Metgrid
#SBATCH --output=%x.%j.out

#module purge
# load intel compiler for C, C++, and FORTRAN

# load WRF_ENV
# load intel compiler for C, C++, and FORTRAN
source /nfs/users/working/corridas/WRF_env.sh

#==========================================================
# Load Simulation Date from Environment 
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

srun --nodes=3 --ntasks=384 --ntasks-per-node=128 --mpi=pmi2   metgrid.exe 2>&1 | tee ${RUNDIR}/metgrib.out.${SLURM_JOBID}

