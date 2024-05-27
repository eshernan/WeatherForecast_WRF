#!/bin/bash

#!/bin/bash -x

#SBATCH --time=05:00:00
#SBATCH --export=ALL
#SBATCH --hint=multithread
#SBATCH --exclusive
#SBATCH --nodes=3
#SBATCH --ntasks=384            ## Number of tasks (analyses) to run
#SBATCH --ntasks-per-node=128


#SBATCH --job-name=real-4.5.3
#SBATCH --output=%x.%j.out
	



#module purge
# load intel compiler for C, C++, and FORTRAN
source /nfs/stor/intel/oneapi/setvars.sh 
source /nfs/users/working/corridas/WRF_env.sh
# load WRF_ENV
export RUN_PATH=/nfs/users/working/wrf4/corridas
#==========================================================
#==========================================================
# Load Simulation Date from Environment 
source /nfs/users/working/wrf4/control/scripts_op/slurm/env_settings.sh

export RUNDIR=$RUN_PATH/20240122-00/real
#mkdir -p $RUNDIR
cd $RUNDIR


export Data_Dir=$RUNDIR

ulimit -s unlimited
ulimit -n 10240

### edit #####################

export OMP_NUM_THREADS=1
#export OMP_STACKSIZE=32G
##############################

srun  --nodes=3 --ntasks=384 --ntasks-per-node=128 --mpi=pmi2   $Data_Dir/real.exe 2>&1 | tee ${RUNDIR}/real.out.${SLURM_JOBID}

