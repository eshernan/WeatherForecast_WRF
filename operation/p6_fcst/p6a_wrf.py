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

import namelists_op
from scripts_op.libs.utils import search_error, delete_files, check_files, mpiexec,slurm_send


def wrf(settings):

    # limpieza
    logging.info("Limpiando viejos archivos:")
    delete_files(settings['globals']['run_fcst_dir'],
                 ("wrf.exe", "*_DATA", "*_DATA_DBL", "*_TBL", "*.TBL", "*_tbl", "*_txt", "ozone*", "tr*",
                  "namelist.input", "wrfbdy_d01", "wrfbdy_d02", "wrfbdy_d03","wrfinput_d01", "wrfinput_d02", "wrfout_d0*"))
    logging.info(" ↳ Hecho")

    # Enlaces y archivos para WPS
    logging.info("Enlazando y copiando archivos:")
    # wrf.exe
    os.symlink(os.path.join(settings['process']['wrf_path'], "wrf_light", "wrf.exe"),
               os.path.join(settings['globals']['run_fcst_dir'], "wrf.exe"))
    # *_DATA
    for _file in glob(os.path.join(settings['process']['wrf_path'], "wrf_light", "*_DATA")):
        os.symlink(_file, os.path.join(settings['globals']['run_fcst_dir'], os.path.basename(_file)))
    # *_DATA_DBL
    for _file in glob(os.path.join(settings['process']['wrf_path'], "wrf_light", "*_DATA_DBL")):
        os.symlink(_file, os.path.join(settings['globals']['run_fcst_dir'], os.path.basename(_file)))
    # *_TBL
    for _file in glob(os.path.join(settings['process']['wrf_path'], "wrf_light", "*_TBL")):
        os.symlink(_file, os.path.join(settings['globals']['run_fcst_dir'], os.path.basename(_file)))
    # *.TBL
    for _file in glob(os.path.join(settings['process']['wrf_path'], "wrf_light", "*.TBL")):
        os.symlink(_file, os.path.join(settings['globals']['run_fcst_dir'], os.path.basename(_file)))
    # *_tbl
    for _file in glob(os.path.join(settings['process']['wrf_path'], "wrf_light", "*_tbl")):
        os.symlink(_file, os.path.join(settings['globals']['run_fcst_dir'], os.path.basename(_file)))
    # *_txt
    for _file in glob(os.path.join(settings['process']['wrf_path'], "wrf_light", "*_txt")):
        os.symlink(_file, os.path.join(settings['globals']['run_fcst_dir'], os.path.basename(_file)))
    # ozone*
    for _file in glob(os.path.join(settings['process']['wrf_path'], "wrf_light", "ozone*")):
        os.symlink(_file, os.path.join(settings['globals']['run_fcst_dir'], os.path.basename(_file)))
    # tr*
    for _file in glob(os.path.join(settings['process']['wrf_path'], "wrf_light", "tr*")):
        os.symlink(_file, os.path.join(settings['globals']['run_fcst_dir'], os.path.basename(_file)))

    # generar el namelist para WRF: wrf.template
    namelists_op.wrf(settings, settings['globals']['run_fcst_dir'])

    # con asimilacion
    if settings['flags']['p5_wrfda'] and settings['flags']['p5a_obsproc']:
        run_wrfda_dir = os.path.join(settings['globals']['run_dir'], "wrfda")
        # wrfbdy_d01
        os.symlink(os.path.join(run_wrfda_dir, "latbc", "wrfbdy_d01"),
                 os.path.join(settings['globals']['run_fcst_dir'], "wrfbdy_d01"))
        # wrfinput_d01
        logging.info(" ↳ Creando enlace dominio 01 de WRFDA ")
        os.symlink(os.path.join(settings['globals']['run_dir'], "wrfda", "da_d01", "wrfvar_output"),
                   os.path.join(settings['globals']['run_fcst_dir'], "wrfinput_d01"))

        if int(settings['process']['domains']) ==2:
            # wrfinput_d02
            os.symlink(os.path.join(settings['globals']['run_dir'], "wrfda", "da_d02", "wrfvar_output"),
                       os.path.join(settings['globals']['run_fcst_dir'], "wrfinput_d02"))
        if int(settings['process']['domains']) ==3:
            logging.info(" ↳ Creando enlace dominio 02 de WRFDA ")
            # wrfinput_d02
            os.symlink(os.path.join(settings['globals']['run_dir'], "wrfda", "da_d02", "wrfvar_output"),
                       os.path.join(settings['globals']['run_fcst_dir'], "wrfinput_d02"))
            # wrfinput_d03
            run_real_dir = os.path.join(settings['globals']['run_dir'], "real")
            # wrfinput
            logging.info(" ↳ Creando enlace dominio 03 de real ")
            os.symlink(os.path.join(settings['globals']['run_dir'], "real", "wrfinput_d03"),
                       os.path.join(settings['globals']['run_fcst_dir'], "wrfinput_d03"))
            
    # sin asimilacion
    else:
        # wrfbdy_d01
        os.symlink(os.path.join(settings['globals']['run_dir'], "real", "wrfbdy_d01"),
                 os.path.join(settings['globals']['run_fcst_dir'], "wrfbdy_d01"))
        # wrfinput_d01
        logging.info(" ↳ Creando enlace dominio 01")
        os.symlink(os.path.join(settings['globals']['run_dir'], "real", "wrfinput_d01"),
                   os.path.join(settings['globals']['run_fcst_dir'], "wrfinput_d01"))

        if int(settings['process']['domains']) == 2:
            # wrfinput_d02
            logging.info(" ↳ Creando enlace dominio 02")
            os.symlink(os.path.join(settings['globals']['run_dir'], "real", "wrfinput_d02"),
                       os.path.join(settings['globals']['run_fcst_dir'], "wrfinput_d02"))
        
        if int(settings['process']['domains']) == 3:
            # wrfinput_d02
            logging.info(" ↳ Creando enlace dominio 02")
            os.symlink(os.path.join(settings['globals']['run_dir'], "real", "wrfinput_d02"),
                       os.path.join(settings['globals']['run_fcst_dir'], "wrfinput_d02"))
            # wrfinput_d03
            logging.info(" ↳ Creando enlace dominio 03")
            os.symlink(os.path.join(settings['globals']['run_dir'], "real", "wrfinput_d03"),
                       os.path.join(settings['globals']['run_fcst_dir'], "wrfinput_d03"))

    logging.info(" ↳ Hecho")

    # run wrf
    logging.info("Corriendo wrf:")
    wrf_log = os.path.join(settings['globals']['run_dir'], "logs", "wrf.log")
    logging.info(" ↳ Ver log en: " + os.path.abspath(wrf_log))
    return_code=slurm_send(settings,"wrf")
    if return_code == 0 or return_code ==1 \
       and not search_error(wrf_log, "ERROR:") \
       and check_files(settings['globals']['run_fcst_dir'], "wrfout_d0*"):
        logging.info(" ↳ Hecho")
    else:
        logging.error(" ↳ Problemas con la corrida de wrf")
        logging.critical(" ↳ Este proceso es necesario para la corrida")
