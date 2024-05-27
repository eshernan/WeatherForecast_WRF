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
import os

from scripts_op.libs.utils import log_format
from scripts_op.p2_preparation import p2a_metar2litR, p2b_sound2litR, p2c_synop2litR, p2d_radiom2litR, p2e_radar2txt, p2f_goes16

def blend_obs_files(settings):
    ### Mezclar todos los archivos litR en uno solo (obs-file)
    obs_file = os.path.join(settings['globals']['run_litr_dir'],
                            "obs.{}".format(settings['globals']['start_date'].strftime("%Y%m%d%H")))
    logging.info('Obs file: '+obs_file)
    with open(obs_file, 'w') as outfile:
        for root, dirs, files in os.walk(os.path.join(settings['globals']['run_litr_dir'])):
            if len(files) != 0:
                files = [x for x in files if x.endswith('2litR.txt')]
                for fname in files:
                    with open(os.path.join(root, fname)) as infile:
                        for line in infile:
                            outfile.write(line)
                        outfile.write("\n")
    logging.info(' ↳ Hecho')


def preparation(settings):

    if not settings['flags']['p2_preparation']:
        return

    logging.info(log_format('PROCESO 2: PREPARACION', level=1))

    settings['globals']['run_litr_dir'] = os.path.join(settings['globals']['run_dir'], "wrfda", "obsproc", "litR")
    
    if not os.path.isdir(settings['globals']['run_litr_dir']):
        os.makedirs(settings['globals']['run_litr_dir'])

    if settings['flags']['p2a_metar2litR']:
        logging.info(log_format('Conversion de Metares 2 litR', level=2))
        p2a_metar2litR.metar2litR(settings)

    if settings['flags']['p2b_sound2litR']:
        logging.info(log_format('Conversion de Sondeos 2 litR', level=2))
        p2b_sound2litR.sound2litR(settings)

    if settings['flags']['p2c_synop2litR']:
        logging.info(log_format('Conversion de Synopticos 2 litR', level=2))
        p2c_synop2litR.synop2litR(settings)

    if settings['flags']['p2d_radiom2litR']:
        logging.info(log_format('Conversion de Radiometros 2 litR', level=2))
        p2d_radiom2litR.radiom2litR(settings)

    logging.info(log_format('Mezclando todos los archivos litR', level=2))
    blend_obs_files(settings)

    settings['globals']['run_radar'] = os.path.join(settings['globals']['run_dir'], "wrfda", "radar")
    if not os.path.isdir(settings['globals']['run_radar']):
        os.makedirs(settings['globals']['run_radar'])
    
    if settings['flags']['p2e_radar2txt']:
        logging.info(log_format('Conversion de radar 2 txt', level=2))
        p2e_radar2txt.radar2txt(settings)

    if settings['flags']['p2f_goes']:
        logging.info(log_format('Recorte de archivos GOES', level=2))
        p2f_goes16.goes16cut(settings)
    
