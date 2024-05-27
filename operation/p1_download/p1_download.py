#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  (c) Copyright FAC-2019
#  Author: Nikolás Cruz, basado en el trabajo de 2016 de
#  Xavier Corredor y Fernando Montana
#
#  Estos script y códigos son de uso exclusivo de la
#  Fuerza Aerea Colombiana (FAC)
#
import logging

from scripts_op.libs.utils import log_format
from scripts_op.p1_download import p1c_sound, p1a_gfs, p1d_synop, p1e_radar


def download(settings):

    if not settings['flags']['p1_download']:
        return

    logging.info(log_format('PROCESO 1: DESCARGA', level=1))
    
    if settings['flags']['p1a_gfs']:
        if settings['globals']['run_type'] == "warm":
            logging.warning("La descarga no se realiza para run_type = warm")
            logging.warning("El proceso continua...")
        if settings['globals']['run_type'] == "cold":
            logging.info(log_format('Descargando archivos GFS', level=2))
            p1a_gfs.gfs(settings)

    if settings['flags']['p1c_sound']:
        logging.info(log_format('Descargando archivos Sounding', level=2))
        p1c_sound.sound(settings)

    if settings['flags']['p1d_synop']:
        logging.info(log_format('Descargando archivos Synops', level=2))
        p1d_synop.synop(settings)

    if settings['flags']['p1e_radar']:
        logging.info(log_format('Descargando archivos de radar', level=2))
        p1e_radar.radar(settings)

