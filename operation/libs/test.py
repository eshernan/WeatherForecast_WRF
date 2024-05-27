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
import shutil
import signal
import socket
from configparser import ConfigParser
from datetime import datetime
from glob import glob




def free_spaces_before_post():

    backup_destination = "/disco2/output/postprocess/"

    ### delete in backup destination
    # XX Gb minimo de espacio libre
    min_free_space = 80 
    t, u, f = shutil.disk_usage(backup_destination)
    free_space = f/1073741824

    while free_space < min_free_space:
   #      print (free_space)
      date_paths = {}
      old_runs = []
      for dir in glob(backup_destination+"/*"):
        try:
           dir_date = datetime.strptime(dir.split("/")[-1], "%Y%m%d-%H")
        except:
           continue
        date_paths[dir_date] = dir
      if date_paths:
           sorted_dates = sorted(date_paths)
           old_runs.append([sorted_dates[0], date_paths[sorted_dates[0]]])

      oldest_date = sorted([x[0] for x in old_runs])[0]
      for _date, _path in old_runs:
        if _date <= oldest_date:
           print("Eliminando: " + _path)  
           # logging.info("Eliminando: " + _path)
           # shutil.rmtree(_path, ignore_errors=True)  
      t, u, f = shutil.disk_usage(backup_destination) 
      free_space = f / 1073741824



free_spaces_before_post()
