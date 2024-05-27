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

import os
import logging
from time import sleep
from urllib.request import urlopen
from bs4 import BeautifulSoup
import ssl
import urllib.request


def sound(settings):
    logging.info('#### Descargando datos Sounding')

    # definicion de la ruta de descarga de sound
    sounding_dir = os.path.join(settings['globals']['data'], "sound")
    if not os.path.isdir(sounding_dir):
        os.makedirs(sounding_dir)

    ### Construye la URL dinamica
    # URL de descarga
    # http://weather.uwyo.edu/cgi-bin/sounding?region=naconf&TYPE=TEXT%3ALIST&YEAR=2016&MONTH=08&FROM=1112&TO=1112&STNM=76644

    d_url = "https://weather.uwyo.edu/cgi-bin/sounding?region=naconf&TYPE=TEXT%3ALIST"
    d_url += "&YEAR=" + settings['globals']['start_date'].strftime("%Y")
    d_url += "&MONTH=" + settings['globals']['start_date'].strftime("%m")
    d_url += "&FROM=" + settings['globals']['start_date'].strftime("%d") + settings['globals']['run_time']
    d_url += "&TO=" + settings['globals']['start_date'].strftime("%d") + settings['globals']['run_time']
    d_url += "&STNM="

    ### Loop de descarga
    for omm_id in [id.strip() for id in settings['download']['sound_omm_ids'].split(',')]:
        logging.info('Descargando datos para la OMM ' + omm_id)
        ## URL de descarga
        url = d_url + omm_id
        file_path = os.path.join(sounding_dir, omm_id)

        attempt = 1
        while True:
            try:
                context = ssl.create_default_context()
                context.check_hostname = False
                context.verify_mode = ssl.CERT_NONE
                https_handler = urllib.request.HTTPSHandler(context=context)
                opener = urllib.request.build_opener(https_handler)
                urllib.request.install_opener(opener)
                response = urlopen(url)
                text = BeautifulSoup(response.read(), "html.parser").get_text()
                f = open(file_path, 'w')
                f.write(text)
                f.close()
                logging.info(' ↳ Descarga finalizada')
                break
            except Exception as err:
                logging.error(" ↳ Problemas descargando el archivo desde: " + url)
                logging.error(" ↳ Error de descarga: " + str(err))
                logging.error(" ↳ Problema al descargar, intentar de nuevo ({}/{})"
                              .format(attempt, settings['download']['max_attempts']))

            if attempt == int(settings['download']['max_attempts']):
                logging.error(" ↳ Intentos maximos de descarga")
                logging.warning(" ↳ Continuar sin este archivo")
                break
            attempt += 1
            sleep(int(settings['download']['wait_retry']) * 60)

    ### Terminando proceso
    logging.info('La descarga de datos Sounding termino')
