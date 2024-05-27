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
from shutil import copyfile
from subprocess import call
import namelists_op

from scripts_op.libs.utils import search_error, delete_files, check_files, mpiexec,slurm_send


def _3dvar(settings, domain):

    _3dvar_domain_dir = os.path.join(settings['globals']['run_wrfda_dir'], "da_d0"+domain)
    if not os.path.isdir(_3dvar_domain_dir):
        os.makedirs(_3dvar_domain_dir)

    # limpieza
    logging.info("Limpiando viejos archivos: para domain {}".format(domain))
    delete_files(_3dvar_domain_dir,
                 ("namelist.input", "LANDUSE.TBL", "be.dat", "da_wrfvar.exe", "ob.ascii",
                  "wrfbdy_d0*", "fg_orig", "fg", "ob.radar", "goes-16-abi-*"))
    logging.info(" ↳ Hecho")

    # generar el namelist para 3dvar: 3dvar_d0X.template
    namelists_op._3dvar(settings, domain)

    # Enlaces y archivos para WRFDA
    logging.info("Enlazando y copiando archivos: para dominio {}".format(domain))
    # LANDUSE.TBL
    os.symlink(os.path.join(settings['process']['wrf_path'], "wrfda_light", "LANDUSE.TBL"),
               os.path.join(_3dvar_domain_dir, "LANDUSE.TBL"))
    # be.dat
    wrfda_light = os.path.join(settings['process']['wrf_path'], "wrfda_light")
    os.symlink(os.path.join(wrfda_light, "be.dat_d0"+domain),
               os.path.join(_3dvar_domain_dir, "be.dat"))
    # da_wrfvar.exe
    os.symlink(os.path.join(settings['process']['wrf_path'], "wrfda_light", "da_wrfvar.exe"),
               os.path.join(_3dvar_domain_dir, "da_wrfvar.exe"))
    # ob.ascii
    os.symlink(os.path.join(settings['globals']['run_dir'], "wrfda", "obsproc",
                            "obs_gts_{}:00:00.3DVAR".format(settings['globals']['start_date'].strftime("%Y-%m-%d_%H"))),
               os.path.join(_3dvar_domain_dir, "ob.ascii"))
    # ob.radar
    if settings['flags']['p5e_radar']:
        os.symlink(os.path.join(settings['globals']['data'], "radar", "wrfda", "obs_radar_clean.txt"),
               os.path.join(_3dvar_domain_dir, "ob.radar"))
    # goes-16-abi-*.nc y enlace radiance_info
    if settings['flags']['p5f_goes']:
        #enlace para archivos goes16
        for i in range(1,11):
            src='OR_ABI-L1b-RadF-M6C%02d_G16_*_COL.nc' % (i+6)
            target='goes-16-abi-%02d.nc' % i
            try:
                #os.symlink(os.path.join(settings['globals']['run_dir'], 'wrfda', 'goes', src),
                #    os.path.join(_3dvar_domain_dir, target))
                os.system('ln -sf '+str(os.path.join(settings['globals']['run_dir'], 'wrfda', 'goes', src))+' '+str(os.path.join(_3dvar_domain_dir, target)))
                logging.warning('ln -sf '+str(os.path.join(settings['globals']['run_dir'], 'wrfda', 'goes', src))+' '+str(os.path.join(_3dvar_domain_dir, target)))
            except Exception as e:
                logging.warning('Imposible enlazar archivo goes16.nc: ' + src)
                logging.warning('verificar ' + os.path.join(settings['globals']['data'], 'wrfda', 'goes', src))
                logging.warning('Exception:', e)
        
        #enlace para carpeta radiance_info
        r_info='radiance_info'
        #os.symlink(os.path.join(settings['process']['wrf_path'], 'wrfda_light', r_info), os.path.join(_3dvar_domain_dir, r_info))
        os.system('ln -sf '+str(os.path.join(settings['process']['wrf_path'], 'wrfda_light', r_info))+' '+str(os.path.join(_3dvar_domain_dir, r_info)))

    if settings['globals']['run_type'] == "cold":
        run_real_dir = os.path.join(settings['globals']['run_dir'], "real")
        # wrfinput
        logging.info("Enlazando y copiando archivos de dominio real{}".format(domain))
        os.symlink(os.path.join(run_real_dir, "wrfinput_d0" + domain),
                   os.path.join(_3dvar_domain_dir, "fg"))

    if settings['globals']['run_type'] == "warm":
        # # wrfbdy
        # if domain == "1":
        #     os.symlink(os.path.join(settings['globals']['run_dir'], "wrfda", "low_d01", "wrfbdy_d01"),
        #              os.path.join(_3dvar_domain_dir, "wrfbdy_d01"))
        # if domain == "2":
        #     os.symlink(os.path.join(settings['globals']['run_dir'], "wrfda", "low_d02", "wrfbdy_d01"),
        #              os.path.join(_3dvar_domain_dir, "wrfbdy_d01"))

        # wrfout -Xh: fg
        os.symlink(os.path.join(settings['globals']['run_wrfda_dir'], "low_d0"+domain, "fg"),
                   os.path.join(_3dvar_domain_dir, "fg"))

    logging.info(" ↳ Hecho")

    # run _3dvar
    logging.info("Corriendo 3dvar:")
    _3dvar_log = os.path.join(settings['globals']['run_dir'], "logs", "3dvar_d0{}.log".format(domain))
    logging.info(" ↳ Ver log en: " + os.path.abspath(_3dvar_log))
    with open(_3dvar_log, "w+") as log:
        return_code=slurm_send(settings,"wrfda_3dvar",domain)
    #    )
    if return_code == 0 \
       and not search_error(_3dvar_log, "ERROR:") \
       and check_files(_3dvar_domain_dir, "wrfvar_output"):
        logging.info(" ↳ Hecho")
    else:
        logging.error(" ↳ Problemas con la corrida de 3dvar")
        logging.critical(" ↳ Este proceso es necesario para la corrida")
