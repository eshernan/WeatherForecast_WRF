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

from scripts_op.libs.utils import log_format
from scripts_op.p6_fcst import p6a_wrf


def fcst(settings):

    if not settings['flags']['p6_fcst']:
        return

    logging.info(log_format('PROCESO 6:  FORECAST', level=1))

    #######################################
    # preparar directorio de corrida
    logging.info(log_format('Preparando directorio de corrida', level=2))

    if not os.path.isdir(settings['globals']['run_dir']):
        os.makedirs(settings['globals']['run_dir'])

    settings['globals']['run_fcst_dir'] = os.path.join(settings['globals']['run_dir'], "fcst")
    if not os.path.isdir(settings['globals']['run_fcst_dir']):
        os.makedirs(settings['globals']['run_fcst_dir'])

    logging.info(" ↳ Hecho")

    #######################################
    # Corrida:
    #   wrf

    # run wrf
    if settings['flags']['p6a_wrf']:
        logging.info(log_format('WRF', level=2))
        p6a_wrf.wrf(settings)
