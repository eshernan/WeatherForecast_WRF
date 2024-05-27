#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  (c) Copyright FAC-2017
#  Authors: Julian Pantoja Clavijo 
#
#  Estos script y códigos son de uso exclusivo de la
#  Fuerza Aerea Colombiana (FAC)
#
import logging
import os
from glob import glob
from shutil import copyfile
from subprocess import call

import namelists_op
from scripts_op.libs.utils import search_error, delete_files, check_files, mpiexec


def arwpost(settings,out_dir):

    # limpieza
    logging.info("Iniciando post procesamiento con ARW Post")

    # generar el namelist para ARW: arwpost.template dominio 1

    namelists_op.arwpost(settings,1,out_dir,settings['globals']['post_dir'],'/disco2/output/ARWpost3/')
    logging.info("se genero el namelist dominio 1 ")

     # run ARW Post dominio 1
    logging.info("Corriendo ARWpost para dominio 1:")
    arw_log = os.path.join(settings['globals']['run_dir'], "logs", "arw.log")
    logging.info("Ver log en: " + os.path.abspath(arw_log))
    with open(arw_log, "w+") as log:
        return_code = call(
            ["./ARWpost.exe"], stdout=log, stderr=log, cwd='/disco2/output/ARWpost3/',
        )
    if return_code == 0 \
       and not search_error(arw_log, "ERROR:") \
       and check_files(settings['globals']['post_dir'], "wrfout_d0*"):
        logging.info("Hecho")
    else:
        logging.error("Problemas con la generacion de los CTL dominio 1")



   # eun ARW Post dominio 2
    namelists_op.arwpost(settings,2,out_dir,settings['globals']['post_dir'],'/disco2/output/ARWpost3/')
    logging.info("se genero el namelist dominio 2 ")
    arw_log = os.path.join(settings['globals']['run_dir'], "logs", "arw.log")
    logging.info("Ver log en: " + os.path.abspath(arw_log))
    with open(arw_log, "w+") as log:
        return_code = call(
            ["./ARWpost.exe"], stdout=log, stderr=log, cwd='/disco2/output/ARWpost3/',
        )
    if return_code == 0 \
       and not search_error(arw_log, "ERROR:") \
       and check_files(settings['globals']['post_dir'], "wrfout_d0*"):
        logging.info("Hecho")
    else:
        logging.error("Problemas con la generacion de los CTL dominio 2")


    logging.info("Hecho")

