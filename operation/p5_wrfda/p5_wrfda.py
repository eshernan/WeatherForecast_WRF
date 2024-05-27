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

from scripts_op.libs.utils import log_format
from scripts_op.p5_wrfda import p5a_obsproc, p5b_low_bc, p5c_3dvar, p5d_lat_bc


def wrfda(settings):

    if not settings['flags']['p5_wrfda']:
        return

    logging.info(log_format('PROCESO 5: WRFDA', level=1))

    #######################################
    # preparar directorio de corrida
    logging.info(log_format('Preparando directorio de corrida', level=2))

    if not os.path.isdir(settings['globals']['run_dir']):
        os.makedirs(settings['globals']['run_dir'])

    settings['globals']['run_litr_dir'] = os.path.join(settings['globals']['run_dir'], "wrfda", "obsproc", "litR")

    settings['globals']['run_wrfda_dir'] = os.path.join(settings['globals']['run_dir'], "wrfda")
    if not os.path.isdir(settings['globals']['run_wrfda_dir']):
        os.makedirs(settings['globals']['run_wrfda_dir'])

    logging.info(" ↳ Hecho")

    #######################################
    # Corrida:
    #   obsproc, low_bc, 3d_var, lat_bc

    # run obsproc
    if settings['flags']['p5a_obsproc']:
        logging.info(log_format('OBSPROC', level=2))
        p5a_obsproc.obsproc(settings)

    # run in all domains
    for domain in range(1, int(settings['process']['wrfda_domains'])+1):
        domain = str(domain)

        # run low_bc
        if settings['flags']['p5b_low_bc']:
            logging.info(log_format('LOW BC FOR DOMAIN 0'+domain, level=2))
            p5b_low_bc.low_bc(settings, domain)

        # run 3dvar
        if settings['flags']['p5c_3dvar']:
            logging.info(log_format('3DVAR FOR DOMAIN 0'+domain, level=2))
            p5c_3dvar._3dvar(settings, domain)

#        ### run draw obs in ncl
#        logging.info('Creando plot de los datos asimilados')
#        with open(os.path.join(os.path.dirname(__file__), 'p5e_draw_obs.ncl'), 'r') as infile:
#            draw_obs = infile.read()
#
#        if settings['globals']['run_type'] == "cold":
#            run_dir = "run"
#        if settings['globals']['run_type'] == "warm":
#            run_dir = "rap"
#
#        # set the variables inside namelist
#        draw_obs = draw_obs.format(
#            start_date=settings['globals']['start_date'].strftime("%Y%m%d"),
#            start_hour=settings['globals']['start_date'].strftime("%H"),
#            domain=domain,
#            run_dir=run_dir,
#        )
#        # save the wps.template file
#        path_to_save = os.path.join(settings['globals']['run_wrfda_dir'], "da_d0"+domain, 'p5e_draw_obs.ncl')
#        outfile = open(path_to_save, "w")
#        outfile.writelines(draw_obs)
#        outfile.close()
#
#        return_code = call(
#            ["ncl", 'p5e_draw_obs.ncl'], cwd=os.path.join(settings['globals']['run_wrfda_dir'], "da_d0"+domain)
#        )
#        if return_code == 0:
#            logging.info(" ↳ Hecho")
#        else:
#            logging.warning(" ↳ No se pudo crear el plot... continuar")
#
    # run lat_bc
    if settings['flags']['p5d_lat_bc']:
        logging.info(log_format('LAT BC', level=2))
        p5d_lat_bc.lat_bc(settings)
