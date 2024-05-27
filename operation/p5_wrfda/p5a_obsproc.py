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
from shutil import copyfile
from subprocess import call

from scripts_op.libs.utils import search_error, delete_files, check_files, slurm_send

import namelists_op

def obsproc(settings):
    # defined path
    settings['globals']['run_obsproc_dir'] = os.path.join(settings['globals']['run_dir'], "wrfda", "obsproc")
    if not os.path.isdir(settings['globals']['run_obsproc_dir']):
        os.makedirs(settings['globals']['run_obsproc_dir'])

    # limpieza
    logging.info("Limpiando viejos archivos:")
    delete_files(settings['globals']['run_obsproc_dir'],
                 ("obserr.txt", "obsproc.exe", "msfc.tbl",
                  "obs.{}".format(settings['globals']['start_date'].strftime("%Y%m%d")),
                  "obs_gts_{}*".format(settings['globals']['start_date'].strftime("%Y-%m-%d"))))
    logging.info(" ↳ Hecho")

    # Enlaces y archivos para WPS
    logging.info("Enlazando y copiando archivos:")
    # obsproc
    os.symlink(os.path.join(settings['process']['wrf_path'], "wrfda_light", "obsproc.exe"),
               os.path.join(settings['globals']['run_obsproc_dir'], "obsproc.exe"))

    wrfda_light = os.path.join(settings['process']['wrf_path'], "wrfda_light")
    # obserr.txt
    os.symlink(os.path.join(wrfda_light, "obserr.txt"),
             os.path.join(settings['globals']['run_obsproc_dir'], "obserr.txt"))
    # msfc.tbl
    os.symlink(os.path.join(wrfda_light, "msfc.tbl"),
             os.path.join(settings['globals']['run_obsproc_dir'], "msfc.tbl"))
    # obs_file
    obs_file = os.path.join(settings['globals']['run_litr_dir'],
                            "obs.{}".format(settings['globals']['start_date'].strftime("%Y%m%d%H")))
    copyfile(obs_file, os.path.join(settings['globals']['run_obsproc_dir'],
                                    "obs.{}".format(settings['globals']['start_date'].strftime("%Y%m%d%H"))))
    # generar el namelist para obsproc: obsproc.template
    namelists_op.obsproc(settings)

    logging.info(" ↳ Hecho")

    # run obsproc
    logging.info("Corriendo obsproc:")
    obsproc_log = os.path.join(settings['globals']['run_dir'], "logs", "obsproc.log")
    logging.info(" ↳ Ver log en: " + os.path.abspath(obsproc_log))
   # with open(obsproc_log, "w+") as log:
    return_code =slurm_send(settings,"wrf_obsproc")
    logging.info("El resultado de la ejecucion es {}".format(return_code))
    if return_code == 0 or return_code ==1 \
       and not search_error(obsproc_log, "ERROR:") \
       and check_files(settings['globals']['run_obsproc_dir'], "obs_gts_{}*".format(settings['globals']['start_date'].strftime("%Y-%m-%d"))):
        logging.info(" ↳ Hecho")
    else:
        logging.error(" ↳ Problemas con la corrida de obsproc")
        logging.critical(" ↳ Este proceso es necesario para la corrida")
