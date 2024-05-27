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
from glob import glob
from shutil import copyfile
from subprocess import call

from scripts_op.libs.utils import search_error, delete_files, mpiexec,slurm_send


def geogrid(settings):

    # limpieza
    # logging.info("Limpiando viejos archivos:")
    # delete_files(wps_path, ("met_em*", "*.log", "FILE*", "GRIBFILE*"))
    # logging.info(" ↳ Hecho")

    # limpieza
    logging.info("Limpiando viejos archivos:")
    delete_files(settings['globals']['run_wps_dir'], ("geo_em*", "geogrid.exe"))
    logging.info(" ↳ Hecho")

    # Enlaces y archivos para WPS
    logging.info("Enlazando archivos:")
    # geogrid
    os.symlink(os.path.join(settings['process']['wrf_path'], "wps_light", "geogrid.exe"),
               os.path.join(settings['globals']['run_wps_dir'], "geogrid.exe"))
    # enlazar geogrid
    if os.path.islink(os.path.join(settings['globals']['run_wps_dir'], "geogrid")):
        os.unlink(os.path.join(settings['globals']['run_wps_dir'], "geogrid"))
    os.symlink(os.path.join(settings['process']['wrf_path'], "wps_light", "geogrid"),
               os.path.join(settings['globals']['run_wps_dir'], "geogrid"))

    logging.info(" ↳ Hecho")

    # run geogrid
    logging.info("Corriendo geogrid:")
    geogrib_log = os.path.join(settings['globals']['run_dir'], "logs", "geogrid.log")
    logging.info(" ↳ Ver log en: " + os.path.abspath(geogrib_log))
    return_code=slurm_send(settings,type="geogrib")
    if return_code == 0 or return_code==1 and not search_error(geogrib_log, "ERROR:"):
        logging.info(" ↳ Hecho")
    else:
        logging.error(" ↳ Problemas con la corrida de geogrid")
        logging.critical(" ↳ Este proceso es necesario para la corrida")
