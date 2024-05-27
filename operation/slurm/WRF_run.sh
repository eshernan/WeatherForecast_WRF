#!/bin/bash

#!/bin/bash -x

#SBATCH --time=05:00:00
#SBATCH --export=ALL
#SBATCH --hint=multithread
#SBATCH --exclusive
#SBATCH --nodes=1
#SBATCH --ntasks=32            ## Number of tasks (analyses) to run

#SBATCH --job-name=WRF-4.5.3
#SBATCH --output=%x.%j.out
	



#module purge
# load intel compiler for C, C++, and FORTRAN
source /nfs/stor/intel/oneapi/setvars.sh 
source /nfs/users/working/corridas/WRF_env.sh
# load WRF_ENV
export RUN_PATH=/nfs/users/working/wrf4/corridas
#==========================================================
# Load Simulation Date from Environment 
#source /nfs/users/working/wrf4/control/scripts_op/slurm/env_settings.sh

export RUNDIR=$RUN_PATH/20240122-00/fcst
#mkdir -p $RUNDIR
cd $RUNDIR


export Data_Dir=$RUNDIR

ulimit -s unlimited
ulimit -n 10240

### edit #####################

export OMP_NUM_THREADS=1
export OMP_STACKSIZE=4G
export PPN=32
export TASK=32
export NODES=1
##############################
#export LD_PRELOAD=/nfs/stor/intel/oneapi/itac/latest/slib/libVT.so
#export VT_LOGFILE_NAME=WRF-trace-MPI.stf
#export VT_LOGFILE_FORMAT=SINGLESTF
#export VT_PCTRACE=5


#mpirun --ntasks=$np --cpus-per-task=$OMP_NUM_THREADS --tasks-per-node=$ppn --distribution=block:block,pack --cpu-bind=verbose  $WRF_DIR/main/wrf.exe 2>&1 | tee wrf.out.${SLURM_JOBID}

#srun -v --mpi=pmi2 --ntasks=$np --cpus-per-task=$OMP_NUM_THREADS --tasks-per-node=$ppn --distribution=block:block,pack --cpu-bind=verbose  $Data_Dir/wrf.exe 2>&1 | tee wrf.out.${SLURM_JOBID}
echo "The start date is $(date +'%D:%T')"
srun --nodes=$NODES --ntasks=$TASK  --tasks-per-node=$PPN --cpus-per-task=$OMP_NUM_THREADS --mpi=pmi2 --distribution=block:block,pack --cpu-bind=verbose  $Data_Dir/wrf.exe 2>&1 | tee wrf.out
echo "The end date is $(date +'%D:%T')"
