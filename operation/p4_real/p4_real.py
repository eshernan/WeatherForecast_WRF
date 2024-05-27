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
from subprocess import call

from scripts_op.libs.utils import log_format, search_error, delete_files, check_files, slurm_send
import namelists_op


def real(settings):

    if not settings['flags']['p4_real']:
        return

    if settings['globals']['run_type'] == "warm":
        logging.warning("p4_real no se realiza para run_type = warm")
        logging.warning("El proceso continua...")
        return

    logging.info(log_format('PROCESO 4: REAL', level=1))

    #######################################
    # preparar directorio de corrida
    logging.info(log_format('Preparando directorio de corrida', level=2))

    if not os.path.isdir(settings['globals']['run_dir']):
        os.makedirs(settings['globals']['run_dir'])

    settings['globals']['run_real_dir'] = os.path.join(settings['globals']['run_dir'], "real")
    if not os.path.isdir(settings['globals']['run_real_dir']):
        os.makedirs(settings['globals']['run_real_dir'])

    logging.info(" ↳ Hecho")

    #######################################
    # Corrida:
    #   real

    logging.info(log_format('REAL', level=2))

    # generar el namelist para WRF: wrf.template
    namelists_op.wrf(settings, settings['globals']['run_real_dir'])

    # limpieza
    logging.info("Limpiando viejos archivos:")
    delete_files(settings['globals']['run_real_dir'], ("wrfinput*", "wrfbdy*", "met_em.d0*", "real.exe"))
    logging.info(" ↳ Hecho")

    # met files
    for geo_file in glob(os.path.join(settings['globals']['run_dir'], "wps", "met_em.d0*")):
        os.symlink(geo_file, os.path.join(settings['globals']['run_real_dir'], os.path.basename(geo_file)))

    # real
    os.symlink(os.path.join(settings['process']['wrf_path'], "wrf_light", "real.exe"),
               os.path.join(settings['globals']['run_real_dir'], "real.exe"))

    # run real
    logging.info("Corriendo real:")
    real_log = os.path.join(settings['globals']['run_dir'], "logs", "real.log")
    logging.info(" ↳ Ver log en: " + os.path.abspath(real_log))
    return_code = slurm_send(settings,type="real")
    # with open(real_log, "w+") as log:
    #return_code = slurm_send(settings,type="real")
    if return_code == 0 or return_code ==1 \
       and not search_error(real_log, "ERROR:") \
       and check_files(settings['globals']['run_real_dir'], ("wrfinput*", "wrfbdy*")):
        logging.info(" ↳ Hecho")
    else:
        logging.error(" ↳ Problemas con la corrida de real")
        logging.critical(" ↳ Este proceso es necesario para la corrida")
