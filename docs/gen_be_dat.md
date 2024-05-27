
# Introducción
Este instructivo se describe el proceso para la creación de archivo de background error be.dat, donde se indica la manera de organizar la información y los procedimiento para la generación.

**Versiones**
- **Resumen:** Creación de los archivos de background error be.dat  
- **Fecha:** Mayo 16 de 2024
- **Autor:** Esteban Hernández B. eshernan@gmail.com
- **Descripción:** En esta versión se incluyen elementos del gestor de slurm, el manejo y actualización de scripts, una parte de automatización y los cambios que fueron requeridos en el código Python para que todo quedara funcionando de manera adecuada. 

## Estructura necesaria para la generación

Se creo una estructura de tres directorios 
```bash 
[run@hpc-master gen_be]$ pwd
/nfs/users/working/wrf4/gen_be
[run@hpc-master gen_be]$ tree -f -d -L 2
├── ./fc
│   ├── ./fc/2024043000
│   │   ├── ./fc/2024043000/wrfout_d01_2024-04-30_12:00:00
│   │   ├── ./fc/2024043000/wrfout_d01_2024-05-01_00:00:00
│   │   ├── ./fc/2024043000/wrfout_d02_2024-04-30_12:00:00
│   │   ├── ./fc/2024043000/wrfout_d02_2024-05-01_00:00:00
│   │   ├── ./fc/2024043000/wrfout_d03_2024-04-30_12:00:00
│   │   └── ./fc/2024043000/wrfout_d03_2024-05-01_00:00:00
│   ├── ./fc/2024043012
│   │   ├── ./fc/2024043012/wrfout_d01_2024-05-01_00:00:00
│   │   ├── ./fc/2024043012/wrfout_d01_2024-05-01_12:00:00
│   │   ├── ./fc/2024043012/wrfout_d02_2024-05-01_00:00:00
│   │   ├── ./fc/2024043012/wrfout_d02_2024-05-01_12:00:00
│   │   ├── ./fc/2024043012/wrfout_d03_2024-05-01_00:00:00
│   │   └── ./fc/2024043012/wrfout_d03_2024-05-01_12:00:00
│   ├── ./fc/2024050100
│   │   ├── ./fc/2024050100/wrfout_d01_2024-05-01_12:00:00
│   │   ├── ./fc/2024050100/wrfout_d01_2024-05-02_00:00:00
│   │   ├── ./fc/2024050100/wrfout_d02_2024-05-01_12:00:00
│   │   ├── ./fc/2024050100/wrfout_d02_2024-05-02_00:00:00
│   │   ├── ./fc/2024050100/wrfout_d03_2024-05-01_12:00:00
│   │   └── ./fc/2024050100/wrfout_d03_2024-05-02_00:00:00
│   ├── ./fc/2024050112
│   │   ├── ./fc/2024050112/wrfout_d01_2024-05-02_00:00:00
│   │   ├── ./fc/2024050112/wrfout_d01_2024-05-02_12:00:00
│   │   ├── ./fc/2024050112/wrfout_d02_2024-05-02_00:00:00
│   │   ├── ./fc/2024050112/wrfout_d02_2024-05-02_12:00:00
│   │   ├── ./fc/2024050112/wrfout_d03_2024-05-02_00:00:00
│   │   └── ./fc/2024050112/wrfout_d03_2024-05-02_12:00:00
│   ├── ./fc/2024050200
│   │   ├── ./fc/2024050200/wrfout_d01_2024-05-02_12:00:00
│   │   ├── ./fc/2024050200/wrfout_d01_2024-05-03_00:00:00
│   │   ├── ./fc/2024050200/wrfout_d02_2024-05-02_12:00:00
│   │   ├── ./fc/2024050200/wrfout_d02_2024-05-03_00:00:00
│   │   ├── ./fc/2024050200/wrfout_d03_2024-05-02_12:00:00
│   │   └── ./fc/2024050200/wrfout_d03_2024-05-03_00:00:00
│   ├── ./fc/2024050212
│   │   ├── ./fc/2024050212/wrfout_d01_2024-05-03_00:00:00
│   │   ├── ./fc/2024050212/wrfout_d01_2024-05-03_12:00:00
│   │   ├── ./fc/2024050212/wrfout_d02_2024-05-03_00:00:00
│   │   ├── ./fc/2024050212/wrfout_d02_2024-05-03_12:00:00
│   │   ├── ./fc/2024050212/wrfout_d03_2024-05-03_00:00:00
│   │   └── ./fc/2024050212/wrfout_d03_2024-05-03_12:00:00
│   ├── ./fc/2024050300
│   │   ├── ./fc/2024050300/wrfout_d01_2024-05-03_12:00:00
│   │   ├── ./fc/2024050300/wrfout_d01_2024-05-04_00:00:00
│   │   ├── ./fc/2024050300/wrfout_d02_2024-05-03_12:00:00
│   │   ├── ./fc/2024050300/wrfout_d02_2024-05-04_00:00:00
│   │   ├── ./fc/2024050300/wrfout_d03_2024-05-03_12:00:00
│   │   └── ./fc/2024050300/wrfout_d03_2024-05-04_00:00:00
│   ├── ./fc/2024050312
│   │   ├── ./fc/2024050312/wrfout_d01_2024-05-04_00:00:00
│   │   ├── ./fc/2024050312/wrfout_d01_2024-05-04_12:00:00
│   │   ├── ./fc/2024050312/wrfout_d02_2024-05-04_00:00:00
│   │   ├── ./fc/2024050312/wrfout_d02_2024-05-04_12:00:00
│   │   ├── ./fc/2024050312/wrfout_d03_2024-05-04_00:00:00
│   │   └── ./fc/2024050312/wrfout_d03_2024-05-04_12:00:00
│   ├── ./fc/2024050400
│   │   ├── ./fc/2024050400/wrfout_d01_2024-05-04_12:00:00
│   │   ├── ./fc/2024050400/wrfout_d01_2024-05-05_00:00:00
│   │   ├── ./fc/2024050400/wrfout_d02_2024-05-04_12:00:00
│   │   ├── ./fc/2024050400/wrfout_d02_2024-05-05_00:00:00
│   │   ├── ./fc/2024050400/wrfout_d03_2024-05-04_12:00:00
│   │   └── ./fc/2024050400/wrfout_d03_2024-05-05_00:00:00
│   └── ./fc/2024050412
│       ├── ./fc/2024050412/wrfout_d01_2024-05-05_00:00:00
│       ├── ./fc/2024050412/wrfout_d01_2024-05-05_12:00:00
│       ├── ./fc/2024050412/wrfout_d02_2024-05-05_00:00:00
│       ├── ./fc/2024050412/wrfout_d02_2024-05-05_12:00:00
│       ├── ./fc/2024050412/wrfout_d03_2024-05-05_00:00:00
│       └── ./fc/2024050412/wrfout_d03_2024-05-05_12:00:00
└── ./run

[run@hpc-master gen_be]
```
se deben crear las dos carpetas principales `fc y run`, con las siguientes funciones:
- `fc`: En esta carpeta se deben colocar las salidas del WRF organizadas por la periodicidad que se configura en el script base asi. 
  - Si se debea analizar las perturbaciones desde el dia N, se deben colocar las simulaciones desde 24 horas horas antes, asi para este ejemplo se analizara el periodo 2024-05-01:00 hasta el 2025-05-04:00. Aqui se deben crear una carpeta por cada periodo de 12 y 24 horas, cada uno con sus respectivas simulaciones de 12 y 24 horas por cada dominio. Estas simulaciones se organizan respecto del nombre de la carpeta, y dentro de ella, las salida del wrfout.
- `run`: En esta carpeta se realizan los calculos temporales de cada una de las etapas del BE, y se crea una estructura temporal,  y al final si todo el proceso de calculo es vàlido se crea el archivo `be.dat` 

Además, de estas dos carpetas también se debe tener una carpeta de trabajo, donde residan los scripts que deben ser copiados de la carpeta de instalación de WRFDA. Esta carpeta quedó ubicada en 
``` /nfs/users/working/wrf4/control/scripts_op/utils/```. 
Dentro de esta carpeta  se debe copiar el script  `gen_be_wrapper.ksh`, este script se copia desde la carpeta de instalación de WRF está ubicada en:
```/nfs/users/working/installers/WRFDA/```

Dentro de este script debemos configurar los siguientes parámetros:
```
export START_DATE=2024050100 # the first perturbation valid date
export END_DATE=2024050400   # the last perturbation valid date
export NUM_LEVELS=41         # = bottom_top = e_vert - 1
export BE_METHOD=NMC
export FC_DIR=/nfs/users/working/wrf4/gen_be/fc   # where wrf forecasts are
export RUN_DIR=/nfs/users/working/wrf4/gen_be/run
export DOMAIN=01             # For nested domains, set to the appropriate domain number
export FCST_RANGE1=24        # Longer forecast time for the NMC method (i.e. for 24-12 NMC, FCST_RANGE1=24, for 36-24 NMC, FCST_RANGE1=36)
export FCST_RANGE2=12        # Shorter forecast time for the NMC method (i.e. for 24-12 NMC, FCST_RANGE2=12, for 36-24 NMC, FCST_RANGE2=24)
export INTERVAL=24           # The interval between your forecast initial times
export STRIDE=1              # STRIDE=1 calculates correlation for every model grid point.
```

Como se observa en este ejemplo, la fecha de inicio es 20240501 a las 00 horas y en la carpeta de FC deben existir una de la fecha 24 horas antes es decir 2024043000 y dentro de ella las salidas del modelo a las 12 horas y las 24 horas siguientes, para cada dominio. 

También el dominio que se desea procesar se debe indicar y que los archivos de salida del modelo de ese dominio deben existir en las respectivas carpetas. 

**Proceso de ejecución**

Una vez se tienen los archivos, en la carpeta `fc`y el script `gen_be_wrapper.ksh`, ajustado con los paths adecuados, se pasa a realizar la ejecución:

`./gen_be_wrapper.ksh`,
la salida de esta ejecucion si es exitosa debe ser similar a:

```
Fri May 17 08:55:04 CDT 2024 Start
WRFVAR_DIR is /nfs/users/working/installers/SHARED/gcc/WRFDAGCC Unversioned directory
RUN_DIR is /nfs/users/working/wrf4/gen_be/run
---------------------------------------------------------------
Run Stage 0: Calculate ensemble perturbations from model forecasts.
---------------------------------------------------------------
Beginning CPU time: Fri May 17 08:55:04 CDT 2024
gen_be_stage0_wrf: Calculating standard perturbation fields valid at time  2024050100
2024043000 /nfs/users/working/wrf4/gen_be/fc/2024043000/wrfout_d01_2024-05-01_00:00:00 /nfs/users/working/wrf4/gen_be/fc/2024043012/wrfout_d01_2024-05-01_00:00:00
gen_be_stage0_wrf: Calculating standard perturbation fields valid at time  2024050200
2024050100 /nfs/users/working/wrf4/gen_be/fc/2024050100/wrfout_d01_2024-05-02_00:00:00 /nfs/users/working/wrf4/gen_be/fc/2024050112/wrfout_d01_2024-05-02_00:00:00
gen_be_stage0_wrf: Calculating standard perturbation fields valid at time  2024050300
2024050200 /nfs/users/working/wrf4/gen_be/fc/2024050200/wrfout_d01_2024-05-03_00:00:00 /nfs/users/working/wrf4/gen_be/fc/2024050212/wrfout_d01_2024-05-03_00:00:00
gen_be_stage0_wrf: Calculating standard perturbation fields valid at time  2024050400
2024050300 /nfs/users/working/wrf4/gen_be/fc/2024050300/wrfout_d01_2024-05-04_00:00:00 /nfs/users/working/wrf4/gen_be/fc/2024050312/wrfout_d01_2024-05-04_00:00:00
Ending CPU time: Fri May 17 08:57:26 CDT 2024
---------------------------------------------------------------
Run Stage 1: Read standard fields, and remove time/ensemble/area mean.
---------------------------------------------------------------
Beginning CPU time: Fri May 17 08:57:26 CDT 2024
Ending CPU time: Fri May 17 08:57:28 CDT 2024
---------------------------------------------------------------
Run Stage 2: Calculate regression coefficients.
---------------------------------------------------------------
Beginning CPU time: Fri May 17 08:57:28 CDT 2024
Ending CPU time: Fri May 17 08:57:29 CDT 2024
---------------------------------------------------------------
Run Stage 2a: Calculate control variable fields.
---------------------------------------------------------------
Beginning CPU time: Fri May 17 08:57:29 CDT 2024
Ending CPU time: Fri May 17 08:57:30 CDT 2024
---------------------------------------------------------------
Run Stage 3: Read 3D control variable fields, and calculate vertical covariances.
---------------------------------------------------------------
Beginning CPU time: Fri May 17 08:57:30 CDT 2024
Ending CPU time: Fri May 17 08:57:39 CDT 2024
---------------------------------------------------------------
Run Stage 4: Calculate horizontal covariances (regional lengthscales).
---------------------------------------------------------------
Beginning CPU time: Fri May 17 08:57:39 CDT 2024
Ending CPU time: Fri May 17 09:35:17 CDT 2024
Ending CPU time: Fri May 17 09:35:17 CDT 2024
---------------------------------------------------------------
Run gen_be_cov2d.
---------------------------------------------------------------

Fri May 17 09:35:21 CDT 2024 Finished
```

El Resultado del archivo `be.dat` se puede localizar en 
```batch
[run@hpc-master run]$ pwd
/nfs/users/working/wrf4/gen_be/run
[run@hpc-master run]$ 
[run@hpc-master run]$ ls *.dat
be.dat
[run@hpc-master run]$
```
Este archivo debe ser copiado a la carpeta wrfda_light, para  cada dominio