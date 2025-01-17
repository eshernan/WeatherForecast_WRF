#!/bin/bash

#!/bin/bash -x

#SBATCH --time=05:00:00
#SBATCH --export=ALL
#SBATCH --hint=multithread
#SBATCH --exclusive
#SBATCH --nodes=2
#SBATCH --ntasks=16            ## Number of tasks (analyses) to run
#SBATCH --ntasks-per-node=8


#SBATCH --job-name=da_wrfvar
#SBATCH --output=%x.%j.out
	



#module purge
# load intel compiler for C, C++, and FORTRAN
source /nfs/stor/intel/oneapi/setvars.sh 
source /nfs/users/working/corridas/WRF_env.sh
# load WRF_ENV
export RUN_PATH=/nfs/users/working/wrf4/corridas

export RUNDIR=$RUN_PATH/20240514-00/wrfda/da_d01
#mkdir -p $RUNDIR
cd $RUNDIR


export Data_Dir=$RUNDIR

export OMP_NUM_THREADS=2
export OMP_STACKSIZE=4G
export PPN=32
export TASK=32
export NODES=1
##############################

echo "The start date is $(date +'%D:%T')" > ${Data_Dir}/../../logs/da_wrfvars.log
srun --nodes=$NODES --ntasks=$TASK --ntasks-per-node=$PPN  --cpus-per-task=$OMP_NUM_THREADS --mpi=pmi2    --distribution=block:block,pack --cpu-bind=verbose  $Data_Dir/da_wrfvar.exe 2>&1 | tee -a $Data_Dir/../../logs/da_wrfvars.log
echo "The end date is $(date +'%D:%T')" >> ${Data_Dir}/../../logs/da_wrfvars.log
