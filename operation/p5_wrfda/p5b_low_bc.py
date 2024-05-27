#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  (c) Copyright FAC-2016
#  Authors: Xavier Corredor
#           Fernando Montana
#
#  Estos script y cóos son de uso exclusivo de la
#  Fuerza Aerea Colombiana (FAC)
#
import logging
import os
from shutil import copyfile
from subprocess import call

from scripts_op.libs.utils import search_error, delete_files, check_files


def low_bc(settings, domain):

    if settings['globals']['run_type'] == "cold":
        logging.warning("low_bc no se realiza para run_type = cold")
        logging.warning("El proceso continua...")
        return

    low_bc_domain_dir = os.path.join(settings['globals']['run_wrfda_dir'], "low_d0"+domain)
    if not os.path.isdir(low_bc_domain_dir):
        os.makedirs(low_bc_domain_dir)

    # limpieza
    logging.info("Limpiando viejos archivos:")
    delete_files(low_bc_domain_dir,
                 ("wrfbdy_d0"+domain, "wrfinput_d0"+domain, "fg_orig", "fg", "da_update_bc.exe", "parame.in"))
    logging.info(" . Hecho")

    # Enlaces y archivos para WPS
    logging.info("Enlazando y copiando archivos:")
    run_wps_dir = os.path.join(settings['globals']['run_dir'], "wps")
    # # wrfbdy
    # copyfile(os.path.join(settings['rap']['run_dir'], "real", "wrfbdy_d01"),
    #          os.path.join(low_bc_domain_dir, "wrfbdy_d01"))
    # wrfinput
    os.symlink(os.path.join(settings['rap']['run_dir'], "real", "wrfinput_d0"+domain),
             os.path.join(low_bc_domain_dir, "wrfinput_d0"+domain))

    # wrfout -Xh: fg
    copyfile(os.path.join(settings['rap']['run_dir'], "fcst",
                          "wrfout_d0{d}_{date}:00:00".format(
                                d=domain, date=settings['globals']['start_date'].strftime("%Y-%m-%d_%H"))),
             os.path.join(low_bc_domain_dir, "fg"))
    os.symlink(os.path.join(settings['rap']['run_dir'], "fcst",
                          "wrfout_d0{d}_{date}:00:00".format(
                                d=domain, date=settings['globals']['start_date'].strftime("%Y-%m-%d_%H"))),
               os.path.join(low_bc_domain_dir, "wrfout_d0{d}_{date}:00:00".format(
                                d=domain, date=settings['globals']['start_date'].strftime("%Y-%m-%d_%H"))))

    # da_update_bc.exe
    os.symlink(os.path.join(settings['process']['wrf_path'], "wrfda_light", "da_update_bc.exe"),
               os.path.join(low_bc_domain_dir, "da_update_bc.exe"))

    # parame.in
    content = """
    &control_param
    da_file            = './fg'
    wrf_input          = './wrfinput_d0{d}'
    domain_id          = 0{d}
    debug              = .false.
    update_lateral_bdy = .false.
    update_low_bdy     = .true.
    update_lsm         = .false.
    iswater            = 17
    /
    """.format(d=domain)

    outfile = open(os.path.join(low_bc_domain_dir, "parame.in"), "w")
    outfile.writelines(content)
    outfile.close()


    logging.info(" . Hecho")

    # run low_bc
    logging.info("Corriendo low_bc:")
    low_bc_log = os.path.join(settings['globals']['run_dir'], "logs", "low_bc_d0{}.log".format(domain))
    logging.info(" . Ver log en: " + os.path.abspath(low_bc_log))
    with open(low_bc_log, "w+") as log:
        return_code = call(
            ["./da_update_bc.exe"], stdout=log, stderr=log, cwd=low_bc_domain_dir,
        )
    if return_code == 0 \
       and not search_error(low_bc_log, "ERROR:") \
       and check_files(low_bc_domain_dir, "fg"):
        logging.info(" . Hecho")
    else:
        logging.error(" . Problemas con la corrida de low_bc")
        logging.critical(" . Este proceso es necesario para la corrida")

