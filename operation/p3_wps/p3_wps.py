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

from scripts_op.libs.utils import log_format, delete_files
from scripts_op.p3_wps import p3a_geogrid, p3b_ungrib, p3c_metgrid
import namelists_op


def wps(settings):

    if not settings['flags']['p3_wps']:
        return

    if settings['globals']['run_type'] == "warm":
        logging.warning("p3_wps no se realiza para run_type = warm")
        logging.warning("El proceso continua...")
        return

    logging.info(log_format('PROCESO 3: WPS', level=1))

    #######################################
    # preparar directorio de corrida
    logging.info(log_format('Preparando directorio de corrida', level=2))

    if not os.path.isdir(settings['globals']['run_dir']):
        os.makedirs(settings['globals']['run_dir'])

    settings['globals']['run_wps_dir'] = os.path.join(settings['globals']['run_dir'], "wps")
    if not os.path.isdir(settings['globals']['run_wps_dir']):
        os.makedirs(settings['globals']['run_wps_dir'])

    # limpieza
    logging.info("Limpiando viejos archivos:")
    delete_files(settings['globals']['run_wps_dir'], ("Vtable", "link_grib.csh"))
    logging.info(" ↳ Hecho")

    # Enlaces y archivos para WPS
    logging.info("Enlazando y copiando archivos:")

    # Vtable
    os.symlink(os.path.join(settings['process']['wrf_path'], "wps_light", "Vtable"),
               os.path.join(settings['globals']['run_wps_dir'], "Vtable"))
    # link_grib
    copyfile(os.path.join(settings['process']['wrf_path'], "wps_light", "link_grib.csh"),
             os.path.join(settings['globals']['run_wps_dir'], "link_grib.csh"))
    logging.info(" ↳ Hecho")

    # generar el namelist para WPS: namelist.wps.template
    namelists_op.wps(settings)

    # link grib
    logging.info("Enlazando GFS con link_grib:")
    logging.info("Data is the following {} and {}".format(settings['globals']['run_wps_dir'],settings['globals']['data']))
    return_code = call(
        ["/usr/bin/csh", os.path.join(settings['globals']['run_wps_dir'], "link_grib.csh"), os.path.join(settings['globals']['data'], "gfs/")],
        cwd=settings['globals']['run_wps_dir'],
    )
    if return_code == 0:
        logging.info(" ↳ Hecho")
    else:
        logging.error(" ↳ Problemas enlazando GFS con link_grib")
        logging.critical(" ↳ Este proceso es necesario para la corrida")

    #######################################
    # Corrida:
    #   geogrid, ungrib, metgrid

    # run geogrid
    if settings['flags']['p3a_geogrid']:
        logging.info(log_format('GEOGRID', level=2))
        p3a_geogrid.geogrid(settings)
    else:
        # copiando los geo_em
        for geo_file in glob(os.path.join(settings['process']['wrf_path'], "wps_light", "geo_em*")):
            logging.info("aqui creaba symlink")
            os.symlink(geo_file, os.path.join(settings['globals']['run_wps_dir'], os.path.basename(geo_file)))
            #geoPath = os.path.basename(geo_file)
            #if os.path.exists(geoPath) and os.path.islink(geoPath):
            #    print("enlace creado")
	    #else:
            #    os.symlink(geo_file, os.path.join(settings['globals']['run_wps_dir'], os.path.basename(geo_file)))

    # run ungrib
    if settings['flags']['p3b_ungrib']:
        logging.info(log_format('UNGRIB', level=2))
        p3b_ungrib.ungrib(settings)

    # run metgrid
    if settings['flags']['p3c_metgrid']:
        logging.info(log_format('METGRID', level=2))
        p3c_metgrid.metgrid(settings)
