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
from subprocess import call,Popen

from scripts_op.libs.utils import search_error, delete_files, check_files


def lat_bc(settings):

    lat_bc_dir = os.path.join(settings['globals']['run_wrfda_dir'], "latbc")
    if not os.path.isdir(lat_bc_dir):
        os.makedirs(lat_bc_dir)

    # limpieza
    logging.info("Limpiando viejos archivos:")
    delete_files(lat_bc_dir,
                 ("wrfvar_output", "wrfbdy_d01","wrfbdy_d02","wrfbdy_d03","wrfinput_d01","wrfinput_d02", "wrfinput_d03"  "da_update_bc.exe", "parame.in", "parame.in.latbdy"))
    logging.info(" ↳ Hecho")

    # Enlaces y archivos para WPS
    logging.info("Enlazando y copiando archivos:")
    run_real_dir = os.path.join(settings['globals']['run_dir'], "real")
    _3dvar_dir = os.path.join(settings['globals']['run_dir'], "wrfda", "da_d01")
    # wrfvar_output
    os.symlink(os.path.join(_3dvar_dir, "wrfvar_output"),
             os.path.join(lat_bc_dir, "wrfvar_output"))

    if settings['globals']['run_type'] == "cold":
        # wrfbdy
        copyfile(os.path.join(run_real_dir, "wrfbdy_d01"),
                 os.path.join(lat_bc_dir, "wrfbdy_d01"))
        os.symlink(os.path.join(run_real_dir, "wrfbdy_d01"),
                   os.path.join(lat_bc_dir, "wrfbdy_d01_bef_up"))

        # wrfinput_d01
        #os.symlink(os.path.join(run_real_dir, "wrfinput_d01"),
        #           os.path.join(lat_bc_dir, "wrfinput_d01"))

    if settings['globals']['run_type'] == "warm":
        # wrfbdy
        copyfile(os.path.join(settings['rap']['run_dir'], "real", "wrfbdy_d01"),
                 os.path.join(lat_bc_dir, "wrfbdy_d01"))
        os.symlink(os.path.join(settings['rap']['run_dir'], "real", "wrfbdy_d01"),
                   os.path.join(lat_bc_dir, "wrfbdy_d01_bef_up"))

        # wrfinput_d01
        #os.symlink(os.path.join(settings['rap']['run_dir'], "real", "wrfinput_d01"),
        #         os.path.join(lat_bc_dir, "wrfinput_d01"))

    # da_update_bc.exe
    os.symlink(os.path.join(settings['process']['wrf_path'], "wrfda_light", "da_update_bc.exe"),
               os.path.join(lat_bc_dir, "da_update_bc.exe"))

    # parame.in
    content = """
    &control_param
     da_file            = './wrfvar_output'
     wrf_bdy_file       = './wrfbdy_d01'
     wrf_input          = './wrfinput_d01'
     domain_id          = 01
     debug              = .false.
     update_lateral_bdy = .true.
     update_low_bdy     = .false
     update_lsm         = .false.
     iswater            = 17
     /
    """

    outfile = open(os.path.join(lat_bc_dir, "parame.in"), "w")
    outfile.writelines(content)
    outfile.close()

    logging.info(" ↳ Hecho")

    # run lat_bc
    logging.info("Corriendo lat_bc:")
    lat_bc_log = os.path.join(settings['globals']['run_dir'], "logs", "lat_bc.log")
    logging.info(" ↳ Ver log en: " + os.path.abspath(lat_bc_log))
    with open(lat_bc_log, "w+") as log:
        return_code = call(
        'source "/nfs/users/working/wrf4/control/scripts_op/slurm/WRF_env.sh";cd '+lat_bc_dir+';./da_update_bc.exe',shell=True,stdout=log,stderr=log)
    if return_code == 0 \
       and not search_error(lat_bc_log, "ERROR:") \
       and check_files(lat_bc_dir, "wrfbdy_d01"):
        logging.info(" ↳ Hecho")
    else:
        logging.error(" ↳ Problemas con la corrida de lat_bc")
        logging.critical(" ↳ Este proceso es necesario para la corrida")
