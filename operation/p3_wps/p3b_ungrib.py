#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  (c) Copyright FAC-2016
#  Authors: Xavier Corredor
#           Fernando Montana
#
#  Estos script y códigos son de uso exclusivo de la
#  Fuerza Aerea Colombiana (FAC)
#
import logging
import os
from subprocess import call

from scripts_op.libs.utils import search_error, delete_files, check_files


def ungrib(settings):

    # limpieza
    run_wps_dir=settings['globals']['run_wps_dir']
    logging.info("Limpiando viejos archivos:")
    delete_files(settings['globals']['run_wps_dir'], ("FILE*", "ungrib.exe"))
    logging.info(" ↳ Hecho")

    # ungrib
    logging.info("Enlazando y copiando archivos:")
    os.symlink(os.path.join(settings['process']['wrf_path'], "wps_light", "ungrib.exe"),
               os.path.join(settings['globals']['run_wps_dir'], "ungrib.exe"))
    logging.info(" ↳ Hecho")

    # run ungrib
    logging.info("Corriendo ungrib: en ruta {}".format(run_wps_dir))
    ungrib_log = os.path.join(settings['globals']['run_dir'], "logs", "ungrib.log")
    logging.info(" ↳ Ver log en: " + os.path.abspath(ungrib_log))
    with open(ungrib_log, "w+") as log:
        return_code = call(
            'source "/nfs/users/working/wrf4/control/scripts_op/slurm/WRF_env.sh";cd '+run_wps_dir+';./ungrib.exe',shell=True, stdout=log, stderr=log) # cwd=run_wps_dir,
        #)
    if return_code == 0 \
       and not search_error(ungrib_log, "ERROR:") \
       and check_files(settings['globals']['run_wps_dir'], "FILE*"):
        logging.info(" ↳ Hecho")
    else:
        logging.error(" ↳ Problemas con la corrida de ungrib")
        logging.critical(" ↳ Este proceso es necesario para la corrida")
