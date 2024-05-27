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
'''
script para:
descargar archivos de radar RAW del servidor de la FAC entre la fecha start_date y end_date en la carpeta RAW_dir
url = 'https://www.simfac.mil.co/imag/RADAR/RAW/' + {year}/{julian day}/
'''
import logging
import os
import datetime as dt
import numpy as np

from scripts_op.libs.utils import log_format


#utilidades temporales
def datetime2julian(d):
    #retornar año y día juliano de la hora d en formato datetime.datetime 
        #pasar hora local a hora juliana
    jul_year = d.timetuple().tm_year
    jul_day = d.timetuple().tm_yday
    return jul_year, jul_day


def list_HTTPS(url, start_date, end_date):
    ''' Listar los archivos IRIS del servidor de la FAC entre la fecha start_date y end_date

    Input:  url = ruta de la FAC con archivos IRIS (str)
            url = 'https://www.simfac.mil.co/imag/RADAR/RAW/'  + {year}/{julian day}/
            start_date = fecha de inicio de la ventana para descarga de datos en hora UTC (datetime.datetime)
            end_date = fecha de fin de la ventana para descarga de datos en hora UTC (datetime.datetime)

    Output: dos listas file_list y url_list con los nombres de los archivos IRIS y las direcciones url respectivamente.
    '''
    import requests
    from bs4 import BeautifulSoup

    ext = ''
    page = requests.get(url).text
    soup = BeautifulSoup(page, 'html.parser')
    url_list = [url + '/' + node.get('href') for node in soup.find_all('a') if node.get('href').endswith(ext)] 
    file_list = [node.get('href') for node in soup.find_all('a') if node.get('href').endswith(ext)]

    url_lst = list()
    file_lst = list()
    for i in range(0, len(file_list)):
        if '.RAW' in file_list[i]:
            date_st = file_list[i][-20:-8] #extraer fecha de archivo: COR170608000002.RAWF1FM --> 170608000002
            date = dt.datetime.strptime(date_st, "%y%m%d%H%M%S")
            if date > start_date and date < end_date:
                url_lst.append(url_list[i])
                file_lst.append(file_list[i])
    return file_lst, url_lst


def IRIS_download(file_name, url, dest_dir='./'):
    ''' Descargar archivos IRIS del servidor de la FAC entre start_date y end_date

    Input:  file_list = nombre del archivo a descargar (str)
            url_list = url del archivo a descargar (str)
            dest_dir = ruta de destino de los archivos IRIS RAW descargados (str)

    Output: archivos IRIS RAW descargados en la carpeta dest_dir
    '''
    import urllib.request
    import shutil
    
    #descargar archivos
    try:
        logging.info('descargando %s' % url)
        with urllib.request.urlopen(url) as response, open(dest_dir + file_name, 'wb') as out_file:
            shutil.copyfileobj(response, out_file)
    except:
        logging.warning('imposible descargar archivo %s' % url_list)
    return


def radar(settings): 
    logging.info('#### Descargando los datos de radar RAW')

    #datos de entrada
    FAC_url = 'https://simfac.fac.mil.co/imag/RADAR/RAW/' # la dirección completa de los datos es: https://www.simfac.mil.co/imag/RADAR/RAW/{year}/{julian day}/
    delta = int(int(settings['assim']['time_window'])/2.0)
    
    # fecha inicial UTC
    ini_date = settings['globals']['start_date']

    #ventana de asimilación
    start_date = ini_date - dt.timedelta(hours=delta)
    end_date = ini_date + dt.timedelta(hours=delta)
    
    #crear directorio para archivos raw
    RAW_dir = os.path.join(settings['globals']['data'], "radar", "RAW/")
    logging.info("Ruta de descarga: "+RAW_dir)
    if not os.path.isdir(RAW_dir):
        os.makedirs(RAW_dir)    

    #construir url con año y dia juliano entre las fechas start_date y end_date
    #pasar datetime a año y dia juliano
    Jyear_start, Jday_start = datetime2julian(start_date)
    Jyear_end, Jday_end = datetime2julian(end_date)

    #listar los archivos del servidor para los días julianos disponibles (entre start_date y end_date)
    if Jyear_start == Jyear_end:
        #estamos en el mismo año
        if Jday_start == Jday_end:
            #estamos en el mismo día
            #descargar datos de https://www.simfac.mil.co/imag/RADAR/RAW/{year}/{julian day}/
            dow_url = FAC_url + str(Jyear_start) + '/' + "{:03d}".format(Jday_start) + '/' 
            try:
                file_lst, url_lst = list_HTTPS(dow_url, start_date, end_date)
            except Exception as e:
                logging.warning('imposible listar archivos RAW de %s' % dow_url)
                logging.warning(e)
                file_lst = list()
        else:
            #estamos en días distintos pero contiguos
            dow_url = FAC_url + str(Jyear_start) + '/' + "{:03d}".format(Jday_start) + '/' 
            try:
                file_lst, url_lst = list_HTTPS(dow_url, start_date, end_date)
            except Exception as e:
                logging.warning('imposible listar archivos RAW de %s' % dow_url)
                logging.warning(e)
                file_lst = list()
            #append de los archivos del segundo día
            dow_url = FAC_url + str(Jyear_start) + '/' + "{:03d}".format(Jday_end) + '/' 
            try:
                file_lst_2, url_lst_2 = list_HTTPS(dow_url, start_date, end_date)
            except Exception as e:
                logging.warning('imposible listar archivos RAW de %s' % dow_url)
                logging.warning(e)
                file_lst_2 = list()
            #join
            file_lst = file_lst + file_lst_2
            url_lst = url_lst + url_lst_2
    else:
        #estamos en distintos años necesariamente son distintos días pero son contiguos (time_window nunca es mayor a un día)
        dow_url = FAC_url + str(Jyear_start) + '/' + "{:03d}".format(Jday_start) + '/' 
        try:
            file_lst, url_lst = list_HTTPS(dow_url, start_date, end_date)
        except Exception as e:
            logging.warning('imposible listar archivos RAW de %s' % dow_url)
            logging.warning(e)
            file_lst = list()
        #append de los archivos del segundo día
        dow_url = FAC_url + str(Jyear_end) + '/' + "{:03d}".format(Jday_end) + '/' 
        try:
            file_lst_2, url_lst_2 = list_HTTPS(dow_url, start_date, end_date)
        except Exception as e:
            logging.warning('imposible listar archivos RAW de %s' % dow_url)
            logging.warning(e)
            file_lst_2 = list()
        #join
        file_lst = file_lst + file_lst_2
        url_lst = url_lst + url_lst_2

    #si la lista de archivos está vacía salir e imprimir en log
    if len(file_lst) > 0:
        logging.info('cantidad de archivos: %d' % len(file_lst))
    else:
        logging.warning('no hay ningún archivo para descargar en %s, entre la fecha %s y %s' % (FAC_url, start_date, end_date))
        return

    #escoger las estaciones disponibles de la lista file_lst usando set()
    stations = list(set([raw[:3] for raw in file_lst]))

    logging.info(log_format('Estaciones: '+str(sorted(stations)), level=2))

    #ordenar la lista file_lst y usar el mismo orden para url_lst
    file_lst = np.array(file_lst)
    url_lst = np.array(url_lst)
    indx = file_lst.argsort() 
    files = file_lst[indx]
    url = url_lst[indx]

    #crear datetime a partir del nombre del archivo 
    times_lst = [x[-20:-8] for x in files]
    times = np.array([dt.datetime.strptime(x, "%y%m%d%H%M%S") for x in times_lst]) - ini_date
    times_seconds = np.array(list(map(lambda x: np.abs(x.total_seconds()), times)))

    #ciclo sobre estaciones
    for st in sorted(stations):
        #escoger los tres tiempos mas cercanos a ini_date para cada estación: 
        #el índice i-ésimo es el mínimo de times_seconds por ende usamos indx-1, indx, e indx+1 como archivos a descargar
        #crear máscara para files dentro de la estación st
        valid_fields = np.char.count(files, st, end = 3)
        valid_names = ~valid_fields.astype(bool)

        #crear masked array para los times_seconds válidos para la estación y extraer índice del mínimo
        temp = np.ma.array(times_seconds, mask=valid_names)
        indx = temp.argmin()

        #descargar archivos RAW para indx-1, indx, e indx+1
        try:
            IRIS_download(files[indx-1], url[indx-1], dest_dir=RAW_dir)
        except Exception as e:
            logging.warning('imposible descargar archivos raw del indice %s', indx-1)
            continue
        try:
            IRIS_download(files[indx], url[indx], dest_dir=RAW_dir)
        except Exception as e:
            logging.warning('imposible descargar archivos raw del indice %s', indx)
            continue
        try:
            IRIS_download(files[indx+1], url[indx+1], dest_dir=RAW_dir)
        except Exception as e:
            logging.warning('imposible descargar archivos raw del indice %s', indx+1)
            continue


    logging.info('La descarga de datos de radar RAW terminó')
    
    return
