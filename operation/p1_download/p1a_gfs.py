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

# Para la descarga de los archivos GFS se usará la
# libreria GFSDownload modificada y ajustada y disponible
# en https://github.com/XavierCLL/gfsDownload.git
# Basada en el codigo original por yoann Moreau y disponible
# en https://github.com/yoannMoreau/gfsDownload
#
# Para ver la instalacion y configuracion de esta libreria
# ver la documentacion.

import logging
import os
from time import sleep

from scripts_op.libs.gfsdownload import utils


def gfs(settings):
    logging.info('#### Descargando los GFS')

    ###########
    # GFS parameter code for download, possibles:
    # 'all','4LFTX','5WAVH','ABSV','ACPCP','ALBDO','APCP','CAPE','CFRZR','CICEP','CIN','CLWMR','CPOFP','CPRAT','CRAIN','CSNOW','CWAT','CWORK','DLWRF','DPT','DSWRF','FLDCP','GFLUX','GUST','HGT','HINDEX','HLCY','HPBL','ICAHT','ICEC','LAND','LFTX','LHTFL','MSLET','O3MR','PEVPR','PLPL','POT','PRATE','PRES','PRMSL','PWAT','RH','SHTFL','SNOD','SOILW','SPFH','SUNSD','TCDC','TMAX','TMIN','TMP','TOZNE','TSOIL','UFLX','UGRD','U-GWD','ULWRF','USTM','USWRF','VFLX','VGRD','V-GWD','VRATE','VSTM','VVEL','VWSH','WATR','WEASD','WILT'
    gfs_code = settings['download']['gfs_code'].split(',')

    # fecha inicial YYYY-MM-DD
    start_date = settings['globals']['start_date'].strftime("%Y-%m-%d")

    # fecha final YYYY-MM-DD
    end_date = settings['globals']['start_date'].strftime("%Y-%m-%d")

    # rango del extend para descargar: ymax xmin ymin xmax
    extend_area = [float(x) for x in settings['download']['gfs_extend_area'].split(',')]

    # niveles
    level_list = settings['download']['gfs_level_list'].split(',')

    # resolucion de rejilla
    grid = settings['download']['gfs_grid']

    # paso
    step = [int(x) for x in settings['globals']['run_time'].split(',')]

    mode = 'forecast'

    # configuracion de los archivos de pronostico horario esto es la
    # seccion del nombre *f000* de los GFS, donde f000 es la hora actual
    # y f001 pronostico a una hora. Aqui se configura la variable
    # forecast_hours con la lista (range) horaria de pronostico a descargar.
    #
    # pronostico a 60 horas archivos cada 3 horas empezando en 0
    forecast_hours = settings['download']['gfs_forecast_hours']

    # definicion de la ruta de descarga para GFS
    gfs_dir = os.path.join(settings['globals']['data'], "gfs")
    logging.info("Ruta de descarga: "+gfs_dir)
    if not os.path.isdir(gfs_dir):
        os.makedirs(gfs_dir)

    ###########
    # revision y asignacion de los parametros
    gfs_code = utils.checkForParams(gfs_code)
    start_date = utils.checkForDate(start_date)
    end_date = utils.checkForDate(end_date)
    extend_area = utils.checkForExtendValidity(extend_area)
    level_list = utils.checkForLevelValidity(level_list)
    grid = utils.checkForGridValidity(grid)
    step = utils.checkForStepValidity(step)

    ###########
    # descarga de los GFS

    attempt = 1
    while True:
        # obtener la estructura y lista de archivos de descarga
        struct = utils.create_request_gfs(start_date, end_date, step, level_list,
                                          grid, extend_area, gfs_code, mode, forecast_hours)
        if len(struct) == 0:
            logging.error(" ↳ Error de coneccion, intentar de nuevo ({}/{})"
                          .format(attempt, settings['download']['max_attempts']))
        elif len(struct[0]) == 0:
            logging.error(" ↳ Datos no disponibles, intentar de nuevo ({}/{})"
                          .format(attempt, settings['download']['max_attempts']))
        else:
            break

        if attempt == int(settings['download']['max_attempts']):
            logging.error("Problemas al descargar")
            logging.critical("Estos datos son necesarios para la corrida")
            break
        attempt += 1
        sleep(150)

    lists_files = []

    for url in struct[0]:
        try:
            namefile = ",".join(gfs_code) + '_' + url.rsplit('.', 1)[1].replace('%2F','') + \
                       '_' + url.split('&')[0].split('.')[-1] + '.grb'
            gfs_path = os.path.join(gfs_dir, namefile)
            
            logging.info("url rsplit : " + url)
            logging.info("Descargando: " + namefile)
            lists_files.append(gfs_path)

            attempt = 1
            while True:
                if utils.GFSDownload(url, gfs_path):
                    logging.info(' ↳ Descarga finalizada')
                    break
                else:
                    logging.error(" ↳ Problema al descargar, intentar de nuevo ({}/{})"
                                  .format(attempt, settings['download']['max_attempts']))
                if attempt == int(settings['download']['max_attempts']):
                    raise Exception("Intentos maximos de descarga")
                attempt += 1
                sleep(int(settings['download']['wait_retry'])*60)

        except Exception as err:
            logging.error("Problemas descargando el archivo desde: " + url)
            logging.error("Error de descarga: " + str(err))
            logging.critical("Estos datos son necesarios para la corrida")

    logging.info('La descarga de datos GFS termino')
