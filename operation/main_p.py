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
# Script principal de corrida del modelo
#
# Llama paso a paso a todos los subprocesos necesarios para la
# corrida de manera secuencial: p1 > p2 > p3 > p4
#
# Toda informacion de corrida, errores y advertencias se almacenaran
# en el archivo log llamado main.log, ningun mensaje sera mostrado
# desde la consola, para ello mirar el segundo ejemplo de ejecusion.
#
# Ejemplo de ejecusion simple:
#   python3 main.py --start-date 2016-01-01 --run-time 00 --run-type warm
#
# Ejemplo de ejecusion en segundo plano:
#   nohup python3 main.py --start-date 2016-08-24 --run-time 00 --run-type warm &
#

import argparse
import logging
import os
import sys
import atexit
from datetime import datetime
from dateutil.relativedelta import relativedelta

project_folder = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if project_folder not in sys.path:
    sys.path.append(project_folder)

from scripts_op import p1_download, p2_preparation, p3_wps, p4_real, p5_wrfda, p6_fcst, p7_post
from scripts_op.libs.utils import log_format, SettingsParser, FileLock, email_report, free_spaces_before_run,  free_spaces_before_post
from scripts_op import api_wrfout	
###############################################################################
#  Carga de las variables desde argumentos de corrida
#
# Estas variables son necesarias como argumento debido a que son dinamicas
# o personalizables en cada corrida
#

parser = argparse.ArgumentParser(
    prog='python3 main.py',
    description='Corrida del Modelo WRF',
    epilog="Fuerza Aerea Colombiana",
    formatter_class=argparse.RawTextHelpFormatter)

parser.add_argument('--start-date', type=str, dest='start_date', help='fecha de la corrida YYYY-MM-DD', required=True)
parser.add_argument('--run-time', type=str, dest='run_time', help='hora de la corrida', required=True)
parser.add_argument('--run-type', type=str, dest='run_type', help='tipo de corrida del modelo (cold or warm)',
                    choices=('warm', 'cold'), required=True)

args = parser.parse_args()

###############################################################################
#  Carga de las variables globales, de descarga, corrida y procesamiento
#
# Si se desea cambiar la configuracion de corrida hagalo en el archivo
# llamado "settings.ini" y no aqui dentro del codigo

settings_parser = SettingsParser()
settings_parser.optionxform = str
settings_parser.read(os.path.join(os.path.dirname(os.path.abspath(__file__)), "settings.ini"))
settings = settings_parser.as_dict()

### guardar las variables de los argumentos dentro de settings

# ruta de los scripts
settings['globals']['scripts_dir'] = os.path.dirname(__file__)
# guarda la hora inicial de corrida
settings['globals']['run_time'] = args.run_time
# guarda la fecha inicial de corrida
settings['globals']['start_date'] = datetime(
    year=int(args.start_date.split('-')[0]), month=int(args.start_date.split('-')[1]),
    day=int(args.start_date.split('-')[2]), hour=int(args.run_time))
# guardar el tipo de corrida
settings['globals']['run_type'] = args.run_type
# asignacion y ajuste de las horas de pronostico en base al tipo de corrida
settings['process']['forecast_hours'] = settings['process']['forecast_hours_'+settings['globals']['run_type']]
# guarda la fecha final de corrida
settings['process']['end_date'] = settings['globals']['start_date'] + \
                              relativedelta(hours=int(settings['process']['forecast_hours']))
# asignar y guardar la hora para el proceso RAP en caliente (run_type=warm)
settings['rap']['run_date'] = settings['globals']['start_date'] - \
                              relativedelta(hours=int(settings['rap']['run_interval']))
# asignar y guardar la ruta para el proceso anterior en frio
# para la corrida RAP en caliente (run_type=warm)
settings['rap']['run_dir'] = settings['globals']['run_dir']\
    .replace("BASE_DIR", settings['globals']['base_dir'])\
    .replace("DATE", settings['rap']['run_date'].strftime("%Y%m%d"))\
    .replace("HOUR", settings['rap']['run_date'].strftime("%H"))

# cambiar de ruto global run a rap si la corrida es en caliente
if settings['globals']['run_type'] == "warm":
    settings['globals']['run_dir'] = settings['globals']['run_dir'].replace("/run/", "/rap/")

### convertir las variables dinamicas con sus respectivos valores provenientes de settings.ini
for k1 in settings.keys():
    for k2 in settings[k1].keys():
        if isinstance(settings[k1][k2], str):
            settings[k1][k2] = settings[k1][k2].replace("BASE_DIR", settings['globals']['base_dir'])
            settings[k1][k2] = settings[k1][k2].replace("DATE", settings['globals']['start_date'].strftime("%Y%m%d"))
            settings[k1][k2] = settings[k1][k2].replace("HOUR", settings['globals']['run_time'])

### convertir las variables booleanas
for k1 in settings.keys():
    for k2 in settings[k1].keys():
        if isinstance(settings[k1][k2], str):
            if settings[k1][k2] == "True":
                settings[k1][k2] = True
            elif settings[k1][k2] == "False":
                settings[k1][k2] = False

###############################################################################
#  Lockfile
#
# El lockfile se encarga que no se ejecuten dos procesos al tiempo, la
# estrategia tomada aqui es si se encuentra con otro proceso, el actual
# mata al proceso viejo para darle via libre a la nueva corrida

lockfile = FileLock(os.path.join(os.path.dirname(os.path.abspath(__file__)), "lock_file"))
settings['globals']['lockfile'] = lockfile
print('diccionario settings:',settings)
###############################################################################
#  Logging de informacion, alertar, errores y errores criticos
#
# info: informacion general del proceso o evento en cuestion
# warning: advertencia de precaucion informativa importante
#          que el usuario debe tener en cuenta y corregirse
#          si es el caso
# error: error de un proceso o evento que se deberia corregir,
#        el proceso continua pero el resultado puede verse
#        considerablemente afectado
# critical: error critico en la que el proceso no puede continuar
#           y se para el proceso
#


class ShutdownHandler(logging.Handler):
    """Exit on critical error"""
    def emit(self, record):
        email_report(settings=settings,
                     files_attached=[os.path.join(settings['globals']['run_dir'], "logs", "main.log")])
        logging.shutdown()
        sys.exit(1)


class StreamToLogger(object):
    """Fake file-like stream object that redirects writes (stdout and stderr)
     to a logger instance."""
    def __init__(self, logger, log_level=logging.INFO):
        self.logger = logger
        self.log_level = log_level
        self.linebuf = ''

    def write(self, buf):
        for line in buf.rstrip().splitlines():
            self.logger.log(self.log_level, line.rstrip())

    def flush(self):
        for handler in self.logger.handlers:
            handler.flush()

# set the logs dir and main log file
if not os.path.isdir(os.path.join(settings['globals']['run_dir'], "logs")):
    os.makedirs(os.path.join(settings['globals']['run_dir'], "logs"))
main_log = os.path.join(settings['globals']['run_dir'], "logs", "main.log")

# setting the logging
logging.basicConfig(filename=main_log, level=logging.DEBUG,
                    format='%(asctime)s %(levelname)s: %(message)s',
                    datefmt='%Y%m%d%H%M', filemode='w')

# set exit on critical error
logging.getLogger().addHandler(ShutdownHandler(level=50))

# redirect all stdout and stderr to logger
sys.stdout = StreamToLogger(logging.getLogger('STDOUT'), logging.INFO)
sys.stderr = StreamToLogger(logging.getLogger('STDERR'), logging.ERROR)

logging.info(log_format('INICIO DEL PROCESO', level=1))
logging.info('CORRIDA PARA EL: {}'.format(args.start_date))
logging.info('HORA DE CORRIDA: {}'.format(args.run_time.zfill(2)))
logging.info('TIPO DE CORRIDA: {}'.format(args.run_type))
logging.info('#'*70)
logging.info('')


###############################################################################
#  Funciones de salida exitosa, con error o terminacion abrupta
#
# liberar el lockfile

def exit_handler():
    lockfile.release()
atexit.register(exit_handler)

###############################################################################
#  Realizar limpieza y liberar espacio en el respaldo y en el espacio de corrida
#
# liberar el lockfile

##free_spaces_before_run(settings)

###############################################################################
#  Descarga
#
# Descarga de los GFS, asimilacion y demas datos necesarios para la corrida

##p1_download.download(settings)

# start lock the process from here
##lockfile.acquire()

###############################################################################
#  Preparacion
#
# Preparacion de datos convirtiendolos a formatos LitR para la entrada de la
# asimilacion del modelo

##p2_preparation.preparation(settings)

###############################################################################
#  WPS
#
# geogrid, ungrib, metgrid

##p3_wps.wps(settings)

###############################################################################
#  REAL
#
# real.exe

##p4_real.real(settings)

###############################################################################
#  WRFDA
#
# Corrida obsproc, low_bc, 3dvar, lat_bc

##p5_wrfda.wrfda(settings)

###############################################################################
#  Rap
#
# Corrida wrf

##p6_fcst.fcst(settings)
###############################################################################
# POST
free_spaces_before_post(settings)
p7_post.post(settings)
#api_wrfout.nc2api(settings)
###############################################################################
#  Finalizando

logging.info(log_format('PROCESO TERMINADO', level=1))
fecha=format(args.start_date)+"-"+format(args.run_time.zfill(2))
os.system('/opt/scripts/mail.sh '+fecha+'')
