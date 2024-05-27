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

# lista de paises a descargar synops para Colombia y alrededores
country_list = {
    "Angui": "Anguilla",
    "Anti": "Antigua y Barbuda",
    "Aru": "Aruba",
    "Baha": "Bahamas, Las",
    "Barb": "Barbados",
    "Beli": "Belize",
    "Berm": "Bermuda",
    "Bona": "Bonaire",
    "Braz": "Brasil",
    "Colom": "Colombia",
    "Cost": "Costa Rica",
    "Cuba": "Cuba",
    "Cura": "Curacao",
    "Dominica": "Dominica",
    "Ecua": "Ecuador",
    "El%20S": "El Salvador",
    "Gren": "Granada",
    "Guad": "Guadalupe",
    "Guat": "Guatemala",
    "Guy": "Guayana",
    "French%20Gui": "Guayana Francesa",
    "Hait": "Haití",
    "Hond": "Honduras",
    "Caym": "Islas Caimán",
    "Virg": "Islas Vírgenes",
    "British%20Vir": "Islas Vírgenes Británicas",
    "Jam": "Jamaica",
    "Marti": "Martinica",
    "Monts": "Montserrat",
    "Nica": "Nicaragua",
    "Pana": "Panamá",
    "Peru": "Perú",
    "Puer": "Puerto Rico",
    "Dominican": "República Dominicana",
    "Saint%20K": "San Cristobal y Nevis",
    "Sint": "San Martín",
    "Saint%20V": "San Vicente y Granadinas",
    "Saint%20L": "Santa Lucía",
    "Suri": "Surinám",
    "Trin": "Trinidad y Tobago",
    "Turks": "Turks y Caicos",
    "Vene": "Venezuela",
}


def synop(settings):
    logging.info('#### Descargando datos SYNOP')

    # definicion de la ruta de descarga de synop
    synop_dir = os.path.join(settings['globals']['data'], "synop")
    logging.info("Ruta de descarga: " + synop_dir)
    if not os.path.isdir(synop_dir):
        os.makedirs(synop_dir)

    ### Construye la URL dinamica
    # ejemplo de URL de descarga
    # http://www.ogimet.com/display_synopsc2.php?estado=Colom&tipo=ALL&ord=REV&nil=SI&fmt=txt&ano=2016&mes=10&day=28&hora=11&anof=2016&mesf=10&dayf=28&horaf=12&enviar=Ver

    # Loop por cada pais de la region a descargar
    files_paths = []
    for acrom, country in country_list.items():

        url = "http://www.ogimet.com/display_synopsc2.php?estado="
        url += acrom
        url += "&tipo=ALL&ord=REV&nil=SI&fmt=txt"

        tdown = "&ano=" + settings['globals']['start_date'].strftime("%Y") + \
                "&mes=" + settings['globals']['start_date'].strftime("%m") + \
                "&day=" + settings['globals']['start_date'].strftime("%d") + \
                "&hora=" + settings['globals']['run_time'] + \
                "&anof=" + settings['globals']['start_date'].strftime("%Y") + \
                "&mesf=" + settings['globals']['start_date'].strftime("%m") + \
                "&dayf=" + settings['globals']['start_date'].strftime("%d") + \
                "&horaf=" + str(int(settings['globals']['run_time'])+1).rjust(2).replace(" ","0") + \
                "&enviar=Ver"

        ## URL de descarga completa
        url += tdown

        file_path = os.path.join(synop_dir, "synop_{}.txt".format(acrom))

        logging.info('Descargando datos Synop para ' + country)

        attempt = 1
        while True:
            try:
                response = urlopen(url)
                text = BeautifulSoup(response.read(), "html.parser").find('pre').text.strip()
                f = open(file_path, 'w')
                f.write(text)
                f.close()
                files_paths.append(file_path)
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

    ### Mezclar todos los archivos en uno solo
    logging.info('Mezclando todos los synops...')
    with open(os.path.join(synop_dir, "synops.txt"), 'w') as outfile:
        for fname in files_paths:
            with open(fname) as infile:
                for num, line in enumerate(infile):
                    if 0 <= num <= 5:
                        continue
                    outfile.write(line)
                outfile.write("\n")
    logging.info(' ↳ Hecho: synops.txt')

    ### Terminando proceso
    logging.info('La descarga de datos Synop termino')

