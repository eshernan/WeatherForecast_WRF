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
from scripts_op.p7_post import p7a_arw, p7b_api
from distutils.dir_util import copy_tree

def post(settings):

    if not settings['flags']['p7_post']:
        return

    logging.info(log_format('PROCESO 7:  POST PROCESAMIENTO', level=1))
    #Se mueven las salidas historicas a una sola ubicacion
    out_dir=settings['globals']['run_dir'].replace(settings['globals']['base_dir'],settings['globals']['backup_destination'])
    logging.info(log_format('Se copian las salidas WRF desde '+settings['globals']['run_dir']+' a '+out_dir, level=1))
    print('Se copian las salidas WRF desde '+settings['globals']['run_dir']+' a '+out_dir)
    copy_tree(settings['globals']['run_dir'],out_dir, preserve_symlinks=1)

    #######################################
    # preparar directorio de corrida
    logging.info(log_format('Preparando para iniciar ARW post', level=2))
    logging.info(log_format('msj',level=2)) 
   

    if settings['globals']['run_type'] == "warm":
       settings['globals']['post_dir'] = settings['globals']['run_dir'].replace("/wrf4/rap/",settings['globals']['post_dir'] )
 
    if settings['globals']['run_type'] == "cold":
       settings['globals']['post_dir'] = settings['globals']['run_dir'].replace("/wrf4/run/",settings['globals']['post_dir'] )
     
    logging.info('Se generaran las salidas en: '+settings['globals']['post_dir'])


    if not os.path.isdir(settings['globals']['post_dir']):
        os.makedirs(settings['globals']['post_dir'])


    logging.info("Hecho")

    #######################################
    # Corrida:
    #   wrf

    # run wrf
#    if settings['flags']['p7a_arw']:
#        logging.info(log_format('ARWPOST', level=2))
#        p7a_arw.arwpost(settings,out_dir)

    if settings['flags']['p7b_api']:
        logging.info(log_format('NC2API', level=2))
        p7b_api.nc2api(settings)
    
    if settings['flags']['p7a_arw']:
        logging.info(log_format('ARWPOST', level=2))
        p7a_arw.arwpost(settings,out_dir)
