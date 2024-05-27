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
from scripts_op.libs.utils import search_error, delete_files, check_files, mpiexec,slurm_send


def metgrid(settings):

    # limpieza
    logging.info("Limpiando viejos archivos:")
    delete_files(settings['globals']['run_wps_dir'], ("met_em*", "metgrid.exe"))
    logging.info(" ↳ Hecho")
    # enlazar metgrid
    logging.info("Enlazando archivos:")
    logging.info("Valores wrf_path{} y run_wps_dir- {}".format(settings['process']['wrf_path'],settings['globals']['run_wps_dir']))
    if os.path.islink(os.path.join(settings['globals']['run_wps_dir'], "metgrid")):
        os.unlink(os.path.join(settings['globals']['run_wps_dir'], "metgrid"))
    os.symlink(os.path.join(settings['process']['wrf_path'], "wps_light", "metgrid"),
               os.path.join(settings['globals']['run_wps_dir'], "metgrid"))

    # metgrid
    os.symlink(os.path.join(settings['process']['wrf_path'], "wps_light", "metgrid.exe"),
               os.path.join(settings['globals']['run_wps_dir'], "metgrid.exe"))
    logging.info(" ↳ Hecho")

    # run metgrid
    logging.info("Corriendo metgrid:")
    metgrid_log = os.path.join(settings['globals']['run_dir'], "logs", "metgrid.log")
    logging.info(" ↳ Ver log en: " + os.path.abspath(metgrid_log))
    #with open(metgrid_log, "w+") as log:
    return_code=slurm_send(settings,type="metgrid")
    logging.info(" ↳ El resultado de la ejecucion fue {}".format(return_code))
    #    )
    if return_code == 0 or return_code==1\
       and not search_error(metgrid_log, "ERROR:") \
       and check_files(settings['globals']['run_wps_dir'], "met_em*"):
        logging.info(" ↳ Hecho")

    else:
        logging.error(" ↳ Problemas con la corrida de metgrid")
        logging.critical(" ↳ Este proceso es necesario para la corrida")
