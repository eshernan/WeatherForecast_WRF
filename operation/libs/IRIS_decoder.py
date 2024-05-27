#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  (c) Copyright FAC-2019
#  Author: Nikolás Cruz, parte de Meteocolombia SAS
#
#  Estos script y códigos son de uso exclusivo de la
#  Fuerza Aerea Colombiana (FAC)
#
'''
script para:
Decodificar archivos IRIS .RAW* de la carpeta RAW_dir en la carpeta dec_dir en archivos de texto para lectura humana mediante la librería wradlib.
Listar propiedades generales de los diccionarios decodificados: nombre del radar, latitud, longitud, altitud radar (en msnm), fecha, # de barridas, #de pixeles radiales, distancia primer radio (en km), distancia ultimo radio (en km), distancia entre radios (en km).
Listar propiedades específicas de cada barrido de los diccionarios decodificados: barrida, angulo phi solicitado (en grados), fecha de barrida, # de radios, angulo de elevacion (en grados).
Filtrar la reflectividad y la velocidad radial usando el filtro Gabella, para filtrar ecos no físicos, e interpolar los puntos removidos. Tanto el filtrado como la interpolación usan la librería wradlib.
Graficar la reflectividad y la velocidad radial crudos (sin unidades físicas) como arreglos 2D para todos los barridos.
Graficar la reflectividad y la velocidad radial (con unidades físicas) en coordenadas polares para todos los barridos usando wradlib.
Graficar los puntos removidos de la reflectividad y la velocidad radial (clutter) en coordenadas polares para todos los barridos usando wradlib.
Graficar la reflectividad y la velocidad radial filtrada e interpolada (con unidades físicas) en coordenadas polares para todos los barridos usando wradlib. 
'''

import matplotlib.pyplot as plt
import numpy as np
import os
import wradlib as wrl

from datetime import datetime, timedelta
from pprint import pprint


def list_dir_dat(dir_path, start_date, end_date):
    ''' Listar los archivos .RAW de un directorio entre la fecha start_date y end_date. 

    Input:  dir_path = diccionario de archivos IRIS RAW 
            start_date = fecha inicial de ventana de asimilación
            end_date = fecha final de ventana de asimilación

    Output: lista de nombres de archivos IRIS RAW en la carpeta dir_path
    '''

    files = []
    # r=root, d=directories, f = files
    for r, d, f in os.walk(dir_path):
        for file in f:
            if '.RAW' in file:
                date_st = file[-20:-8] #extraer fecha de archivo: COR170608000002.RAWF1FM --> 170608000002 
                date = datetime.strptime(date_st, "%y%m%d%H%M%S")
                if date > start_date and date < end_date:
                    files.append(file)

    return files

def IRIS_download(url, start_date, end_date, dest_dir='./'):
    ''' Descargar archivos IRIS del servidor de la FAC entre start_date y end_date

        Input:  url = ruta de la FAC con archivos IRIS (str)
                url = 'https://www.simfac.mil.co/imag/tempo/MC/radar/' 
                start_date = fecha de inicio de la ventana para descarga de datos (datetime.datetime)
                end_date = fecha de fin de la ventana para descarga de datos (datetime.datetime)
                dest_dir = ruta de destino de los archivos IRIS RAW descargados (str)

        Output: archivos IRIS RAW descargados en la carpeta dest_dir
    '''

    def list_HTTPS(url, start_date, end_date):
        ''' Listar los archivos IRIS del servidor de la FAC entre la fecha start_date y end_date

            Input:  url = ruta de la FAC con archivos IRIS (str)
                    url = 'https://www.simfac.mil.co/imag/tempo/MC/radar/'
                    start_date = fecha de inicio de la ventana para descarga de datos (datetime.datetime)
                    end_date = fecha de fin de la ventana para descarga de datos (datetime.datetime)


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
                date = datetime.strptime(date_st, "%y%m%d%H%M%S")
                if date > start_date and date < end_date:
                    url_lst.append(url_list[i])
                    file_lst.append(file_list[i])
        return file_lst, url_lst
    
    import urllib.request
    import shutil
        
    #leer carpeta url y enlistar archivos
    file_list, url_list = list_HTTPS(url, start_date, end_date)
    
    if len(file_list) > 0:
        pprint(file_list)
        print('cantidad de archivos: %d' % len(file_list))
    else:
        print('no hay ningun archivo para descargar en %s' % url)
        return

    #descargar archivos
    for i in range(0,len(url_list)):
        try:
            print('descargando %s' % url_list[i])
            with urllib.request.urlopen(url_list[i]) as response, open(dest_dir + file_list[i], 'wb') as out_file:
                shutil.copyfileobj(response, out_file)
        except:
            print('imposible descargar archivo %s' % url_list[i])
    return
        

def IRIS_decode_and_save(IRIS_fn, IRIS_dir='./', dest_dir='./'):
    ''' Decodificar el archivo IRIS_fn usando wradlib y guardar el diccionario
        decodificado como un archivo de texto en dest_dir.

    Input:  IRIS_dir = ruta del archivo IRIS a decodificar 
            IRIS_fn = nombre del archivo IRIS a decodificar
            dest_dir = ruta de destino del archivo IRIS decodificado

    Output: archivo IRIS decodificado en un diccionario y guardado en un archivo de texto en dest_dir
    '''

    f_content = wrl.io.iris.read_iris(IRIS_dir + IRIS_fn, loaddata = {'moment': ['DB_DBZ', 'DB_VEL']}, rawdata=False)
    #Imprimir diccionario a archivo
    with open(dest_dir + IRIS_fn + '.txt', 'w') as f:
        for key in f_content.keys():
            pprint('IRIS_key = ' + key, f)
            pprint(f_content[key], f)

    return f_content

def IRIS_decode(IRIS_fn, IRIS_dir='./'):
    ''' Decodificar el archivo IRIS_fn usando wradlib y retornar el diccionario decodificado.

    Input:  IRIS_dir = ruta del archivo IRIS a decodificar 
            IRIS_fn = nombre del archivo IRIS a decodificar

    Output: archivo IRIS decodificado en un diccionario
    '''

    print('decodificando %s' % IRIS_dir + IRIS_fn)
    return wrl.io.iris.read_iris(IRIS_dir + IRIS_fn, loaddata = {'moment': ['DB_DBZ', 'DB_VEL']}, rawdata=False)

def plot_DBZ_and_VEL(DBZ, VEL, IRIS_fn, plot_dir='./', sweep=1):
    ''' Graficar la reflectividad raw y la velocidad radial raw del archivo IRIS_fn 
        en la carpeta plot_dir para el barrido sweep.

    Input:  DBZ = array de reflectividades 
            VEL = array de velocidades radiales
            plot_dir = directorio de destino de las imagenes (srt)
            IRIS_fn = nombre del archivo IRIS (str)
            sweep = # de barrida (int)

    Output: gráficas reflectividad_%(fn)s_sweep_%(sw)s.png y velocidad_radial_%(fn)s_sweep_%(sw)s.png
            en la carpeta plot_dir
    '''
    
    print('barrido %s' % sweep)
    print('###   Graficar reflectividad  ###')
    fig = plt.figure(figsize=(16,9))
    c = plt.imshow(DBZ, origin='lower')
    fig.colorbar(c)
    plt.grid('true')
    plt.title('reflectividad DBZ para %(fn)s barrido %(sw)s' % dict(fn=IRIS_fn, sw=sweep))
    plot_name = "reflectividad_%(fn)s_sweep_%(sw)s.png" \
            % dict(fn=IRIS_fn, sw=sweep)
    plt.savefig(plot_dir + plot_name, dpi=300, papertype='letter')
    plt.close()

    print('###   Graficar velocidad radial  ###')
    fig = plt.figure(figsize=(16,9))
    c = plt.imshow(VEL, origin='lower')
    fig.colorbar(c)
    plt.grid('true')
    plt.title('velocidad radial VEL para %(fn)s barrido %(sw)s' % dict(fn=IRIS_fn, sw=sweep))
    plot_name = "velocidad_radial_%(fn)s_sweep_%(sw)s.png" \
            % dict(fn=IRIS_fn, sw=sweep)
    plt.savefig(plot_dir + plot_name, dpi=300, papertype='letter')
    plt.close()

    print('###   Hecho  ###')
    return
    

def plot_extra_data(IRIS_fn, radar_dict, var='DB_DBZ', plot_dir='./', sweep=1):
    ''' Graficar el ángulo azimutal inicial y final, elevación inicia y final, y dtime del archivo IRIS_fn 
        y variable var en la carpeta plot_dir para el barrido sweep.

    Input:  var = 'DB_DBZ' o 'DB_VEL' 
            radar_dict = diccionario decodificado de IRIS_fn (ver IRIS_decode)
            plot_dir = directorio de destino de las imagenes (srt)
            IRIS_fn = nombre del archivo IRIS (str)
            sweep = # de barrida (int)
            xlim = limite en pixeles para los archivos raw en la coordenada radial (int)

    Output: gráficas reflectividad_%(fn)s_sweep_%(sw)s.png y velocidad_radial_%(fn)s_sweep_%(sw)s.png
            en la carpeta plot_dir
    '''

    azi_start = radar_dict['data'][sweep]['sweep_data'][var]['azi_start']
    azi_stop = radar_dict['data'][sweep]['sweep_data'][var]['azi_stop']
    ele_start = radar_dict['data'][sweep]['sweep_data'][var]['ele_start']
    ele_stop = radar_dict['data'][sweep]['sweep_data'][var]['ele_stop']
    dtime = radar_dict['data'][sweep]['sweep_data'][var]['dtime']
    
    print('barrido %s' % sweep)
    print('###   Graficar azimutal %s  ###' % var)
    fig = plt.figure(figsize=(16,9))
    plt.plot(azi_start, marker='o', markersize=2, linestyle='--', linewidth=0.5, color='g')
    plt.plot(azi_stop, marker='o', markersize=2, linestyle='--', linewidth=0.5, color='r')
    plt.grid('true')
    plt.title('azimutal %(var)s para %(fn)s barrido %(sw)s' % dict(var=var, fn=IRIS_fn, sw=sweep))
    plot_name = "azi_%(var)s_%(fn)s_sweep_%(sw)s.png" \
            % dict(var=var, fn=IRIS_fn, sw=sweep)
    plt.savefig(plot_dir + plot_name, dpi=300, papertype='letter')
    plt.close()

    print('###   Graficar elevación %s  ###' % var)
    fig = plt.figure(figsize=(16,9))
    plt.plot(ele_start, marker='o', markersize=2, linestyle='--', linewidth=0.5, color='g')
    plt.plot(ele_stop, marker='o', markersize=2, linestyle='--', linewidth=0.5, color='r')
    plt.grid('true')
    plt.title('elevacion %(var)s para %(fn)s barrido %(sw)s' % dict(var=var, fn=IRIS_fn, sw=sweep))
    plot_name = "ele_%(var)s_%(fn)s_sweep_%(sw)s.png" \
            % dict(var=var, fn=IRIS_fn, sw=sweep)
    plt.savefig(plot_dir + plot_name, dpi=300, papertype='letter')
    plt.close()

    print('###   Graficar dtime %s  ###' % var)
    fig = plt.figure(figsize=(16,9))
    plt.plot(dtime, marker='o', markersize=2, linestyle='--', linewidth=0.5, color='b')
    plt.grid('true')
    plt.title('dtime %(var)s para %(fn)s barrido %(sw)s' % dict(var=var, fn=IRIS_fn, sw=sweep))
    plot_name = "dtime_%(var)s_%(fn)s_sweep_%(sw)s.png" \
            % dict(var=var, fn=IRIS_fn, sw=sweep)
    plt.savefig(plot_dir + plot_name, dpi=300, papertype='letter')
    plt.close()

    print('###   Hecho  ###')
    return
    

def print_general_data(radar_dict):
    '''  Imprimir en pantalla la informacion general (común a todas las barridas) 
        del diccionario radar_dict:
        - nombre del sitio, latitud, longitud, altitud del radar, fecha de ingesta.
        - # de barridas, bins máximos, distancia del primer bin, distancia del último bien, distancia entre bins.

    Input:  radar_dict = diccionario decodificado de IRIS_fn (ver IRIS_decode)
            
    Output: Informacion general de radar_dict impresa en pantalla
    '''

    lat = radar_dict['ingest_header']['ingest_configuration']['latitude_radar']
    lon = radar_dict['ingest_header']['ingest_configuration']['longitude_radar']
    file_time = radar_dict['product_hdr']['product_configuration']['sweep_ingest_time']
    max_sweep =  radar_dict['ingest_header']['ingest_configuration']['number_sweeps_completed']
    site_name = radar_dict['ingest_header']['ingest_configuration']['site_name']
    site_height = radar_dict['ingest_header']['ingest_configuration']['height_site'] #en metros
    radar_height = radar_dict['ingest_header']['ingest_configuration']['height_radar'] #en metros
    bins = radar_dict['ingest_header']['task_configuration']['task_range_info']['number_output_bins'] # longitud en pixeles
    dist_first_bin = radar_dict['ingest_header']['task_configuration']['task_range_info']['range_first_bin']/100000.0 # en kilometros
    dist_last_bin = radar_dict['ingest_header']['task_configuration']['task_range_info']['range_last_bin']/100000.0 # en kilometros
    bins_step = radar_dict['ingest_header']['task_configuration']['task_range_info']['step_output_bins']/100000.0 # en kilometros

    print('nombre del radar: %s, latitud: %s, longitud: %s, altitud radar: %s msnm, fecha: %s' % (site_name, lat, lon, site_height + radar_height, file_time))
    print('# de barridas: %s, # de pixeles radiales: %s, distancia primer radio: %s km, distancia ultimo radio: %s km, distancia entre radios: %s km' \
        % (max_sweep, bins, dist_first_bin, dist_last_bin, bins_step))
    return

def print_sweep_spec_data(radar_dict, sweep=1):
    ''' Imprimir en pantalla la informacion específica por barrida 
        del diccionario radar_dict en la barrida sweep:
        - barrida, ángulo phi en grados, hora de ingesta, # de bins, elevación (similar al ángulo phi)

    Input:  radar_dict = diccionario decodificado de IRIS_fn (ver IRIS_decode)
            
    Output: Informacion específica de la barrida sweep de radar_dict impresa en pantalla
    '''

    phi_angle = radar_dict['data'][sweep]['ingest_data_hdrs']['DB_DBZ']['fixed_angle'] # varia con cada sweep
    sweep_time = radar_dict['data'][sweep]['ingest_data_hdrs']['DB_DBZ']['sweep_start_time'] # varia con cada sweep
    bins_inside_data = radar_dict['data'][sweep]['sweep_data']['DB_DBZ']['rbins'][0] # varia con cada sweep
    elevation_inside_data = radar_dict['data'][sweep]['sweep_data']['DB_DBZ']['ele_start'][0] # varia con cada sweep

    print('\tbarrida: %s, angulo phi solicitado: %s grados, hora de barrida: %s, # de radios: %s, angulo de elevacion: %s' \
        % (sweep, phi_angle, sweep_time, bins_inside_data, elevation_inside_data))
    return

def calc_sph_components(radar_dict, var='DB_DBZ', sweep=1):
    ''' Calcular las componentes esféricas de var (contenidas en radar_dict) para la barrida sweep
        con magnitudes físicas (radii = m, theta = grados)

    Input:  radar_dict = diccionario decodificado de IRIS_fn (ver IRIS_decode)
            var = 'DB_DBZ' o 'DB_VEL'
            sweep = barrido (int)
            
    Output: arrays radii, theta y phi
    '''    

    #promediar azi_start y azi_stop para calcular theta en grados
    azi_start = radar_dict['data'][sweep]['sweep_data'][var]['azi_start']
    azi_stop = radar_dict['data'][sweep]['sweep_data'][var]['azi_stop']
    #promediar ele_start y ele_stop para calcular phi en grados
    ele_start = radar_dict['data'][sweep]['sweep_data'][var]['ele_start'][0]
    ele_stop = radar_dict['data'][sweep]['sweep_data'][var]['ele_stop'][0]
    _phi = (ele_start + ele_stop)/2.0
    theta = []
    phi = []
    #corrección para salto entre 0 y 2pi para theta
    for ang in range(0, len(azi_start)):
        if azi_start[ang] - azi_stop [ang] < 1e-8:
            theta.append((azi_start[ang] + azi_stop [ang])/2.0)
        else:
            theta.append(((azi_start[ang] - 360) + azi_stop [ang])/2.0)
            #agregar el mismo phi para la barrida (elevación constante)
        phi.append(_phi)
    theta = np.array(theta) #en grados
    phi = np.array(phi) #en grados

    #calcular distancia radial en metros
    dist_first_bin = radar_dict['ingest_header']['task_configuration']['task_range_info']['range_first_bin']/100.0 # en metros
    dist_last_bin = radar_dict['ingest_header']['task_configuration']['task_range_info']['range_last_bin']/100.0 # en metros
    bins_step = radar_dict['ingest_header']['task_configuration']['task_range_info']['step_output_bins']/100.0 # en metros

    radii = np.arange(dist_first_bin + bins_step/2.0, dist_last_bin + bins_step/2.0, bins_step) #ubicado en el centroide del bin
    return radii, theta, phi

def plot_sph_components(IRIS_fn, radar_dict, var='DB_DBZ', plot_dir='./', sweep=1):
    ''' Graficar PPI de la variable var en la carpeta plot_dir para el barrido sweep.

    Input:  var = 'DB_DBZ' o 'DB_VEL' 
            radar_dict = diccionario decodificado de IRIS_fn (ver IRIS_decode)
            plot_dir = directorio de destino de las imagenes (srt)
            IRIS_fn = nombre del archivo IRIS (str)
            sweep = # de barrida (int)

    Output: gráficas reflectividad_raw_%(fn)s_sweep_%(sw)s.png o velocidad_radial_raw_%(fn)s_sweep_%(sw)s.png
            en la carpeta plot_dir segun var = 'DB_DBZ' o 'DB_VEL' respectivamente
    '''

    if var == 'DB_DBZ':
        # mask data array for better presentation
        data = radar_dict['data'][sweep]['sweep_data'][var]['data']
        mask_ind = np.where(data <= np.nanmin(data))
        data[mask_ind] = np.nan
        ma = np.ma.array(data, mask=np.isnan(data))
        np.ma.set_fill_value(ma, -32.)
    elif var == 'DB_VEL':
        ma  = radar_dict['data'][sweep]['sweep_data'][var]['data']
    else:
        print('variable var inexistente: %s' %var)
        return

    # read data
    radii, theta, phi = calc_sph_components(radar_dict, var=var, sweep=sweep)
    lat = radar_dict['ingest_header']['ingest_configuration']['latitude_radar']
    lon = radar_dict['ingest_header']['ingest_configuration']['longitude_radar']
    site_height = radar_dict['ingest_header']['ingest_configuration']['height_site'] #en metros
    radar_height = radar_dict['ingest_header']['ingest_configuration']['height_radar'] #en metros
    #epsg=wrl.georef.epsg_to_osr(21896) # proyección para colombia https://epsg.io/21896

    fig = plt.figure(figsize=(10,8))
    cgax, pm = wrl.vis.plot_ppi(ma, r=radii, rf=1e3, az=theta, elev=phi, fig=fig, proj='cg', site=(lon, lat, site_height + radar_height))
    caax = cgax.parasites[0]
    if var == 'DB_DBZ':
        t = plt.title('reflectividad para %(fn)s barrido %(sw)s - raw' % dict(fn=IRIS_fn, sw=sweep))
    else:
        t = plt.title('velocidad radial para %(fn)s barrido %(sw)s - raw' % dict(fn=IRIS_fn, sw=sweep))
    t.set_y(1.1)
    cbar = plt.gcf().colorbar(pm, pad=0.075)
    caax.set_xlabel('hacia el oriente [km]')
    caax.set_ylabel('hacia el horte [km]')
    plt.text(1.0, 1.05, 'azimutal', transform=caax.transAxes, va='bottom',
        ha='right')
    if var == 'DB_DBZ':
        cbar.set_label('reflectividad [dBZ]')
        plot_name = "reflectividad_raw_%(fn)s_sweep_%(sw)s.png" \
            % dict(fn=IRIS_fn, sw=sweep)
    else:
        cbar.set_label('velocidad radial [m/s]')
        plot_name = "velocidad_radial_raw_%(fn)s_sweep_%(sw)s.png" \
            % dict(fn=IRIS_fn, sw=sweep)
    plt.savefig(plot_dir + plot_name, dpi=300, papertype='letter')
    plt.close()
    
    return

def plot_clutter(IRIS_fn, radar_dict, var='DB_DBZ', plot_dir='./', sweep=1):
    ''' Graficar clutter del fitlrado Gabella PPI de la variable var en la carpeta plot_dir para el barrido sweep.

    Input:  var = 'DB_DBZ' o 'DB_VEL' 
            radar_dict = diccionario decodificado de IRIS_fn (ver IRIS_decode)
            plot_dir = directorio de destino de las imagenes (srt)
            IRIS_fn = nombre del archivo IRIS (str)
            sweep = # de barrida (int)

    Output: gráficas reflectividad_clutter_%(fn)s_sweep_%(sw)s.png o velocidad_radial_clutter_%(fn)s_sweep_%(sw)s.png
            en la carpeta plot_dir segun var = 'DB_DBZ' o 'DB_VEL' respectivamente
    '''
    
    if var == 'DB_DBZ' or var == 'DB_VEL':
        ma = radar_dict['data'][sweep]['sweep_data'][var]['data']
    else:
        print('variable var inexistente: %s' %var)
        return
    # read data
    radii, theta, phi = calc_sph_components(radar_dict, var=var, sweep=sweep)
    lat = radar_dict['ingest_header']['ingest_configuration']['latitude_radar']
    lon = radar_dict['ingest_header']['ingest_configuration']['longitude_radar']
    site_height = radar_dict['ingest_header']['ingest_configuration']['height_site'] #en metros
    radar_height = radar_dict['ingest_header']['ingest_configuration']['height_radar'] #en metros
    #epsg=wrl.georef.epsg_to_osr(21896) # proyección para colombia https://epsg.io/21896
    
    #filtrar usando filtro gabella
    ma_clutter = wrl.clutter.filter_gabella(ma, tr1=12, n_p=6, tr2=1.1)

    fig = plt.figure(figsize=(10,8))
    cgax, pm = wrl.vis.plot_ppi(ma_clutter, r=radii, rf=1e3, az=theta, elev=phi, fig=fig, proj='cg', site=(lon, lat, site_height + radar_height), cmap=plt.cm.gray)
    caax = cgax.parasites[0]
    if var == 'DB_DBZ':
        t = plt.title('clutter reflectividad para %(fn)s barrido %(sw)s' % dict(fn=IRIS_fn, sw=sweep))
    else:
        t = plt.title('clutter velocidad radial para %(fn)s barrido %(sw)s' % dict(fn=IRIS_fn, sw=sweep))
    t.set_y(1.1)
    cbar = plt.gcf().colorbar(pm, pad=0.075)
    caax.set_xlabel('hacia el oriente [km]')
    caax.set_ylabel('hacia el horte [km]')
    plt.text(1.0, 1.05, 'azimutal', transform=caax.transAxes, va='bottom',
        ha='right')
    if var == 'DB_DBZ':
        cbar.set_label('reflectividad [dBZ]')
        plot_name = "reflectividad_clutter_%(fn)s_sweep_%(sw)s.png" \
            % dict(fn=IRIS_fn, sw=sweep)
    else:
        cbar.set_label('velocidad radial [m/s]')
        plot_name = "velocidad_radial_clutter_%(fn)s_sweep_%(sw)s.png" \
            % dict(fn=IRIS_fn, sw=sweep)
    plt.savefig(plot_dir + plot_name, dpi=300, papertype='letter')
    plt.close()
    
    return ma_clutter

def clean_data(radar_dict, var='DB_DBZ', sweep=1):
    ''' limpiar la variable var filtrada usando Gabella e interpolada para el barrido sweep.

    Input:  var = 'DB_DBZ' o 'DB_VEL' 
            radar_dict = diccionario decodificado de IRIS_fn (ver IRIS_decode)
            sweep = # de barrida (int)

    Output: arreglo de datos limpio
    '''
    if var == 'DB_DBZ' or var == 'DB_VEL':
        data = radar_dict['data'][sweep]['sweep_data'][var]['data']
    else:
        print('variable var inexistente: %s' %var)
        return
    
    #filtrar usando filtro gabella
    data_clutter = wrl.clutter.filter_gabella(data, tr1=12, n_p=6, tr2=1.1)

    #interpolar datos filtrados
    data_clean = wrl.ipol.interpolate_polar(data, data_clutter)

    if var == 'DB_DBZ':
        # mask data array for better presentation
        mask_ind = np.where(data_clean <= np.nanmin(data_clean))
        data_clean[mask_ind] = np.nan
        data_cl = np.ma.array(data_clean, mask=np.isnan(data_clean))
        np.ma.set_fill_value(data_cl, -32.)
    else:
        data_cl = data_clean

    return data_cl

def plot_clean_data(IRIS_fn, radar_dict, var='DB_DBZ', plot_dir='./', sweep=1):
    ''' Graficar PPI de la variable var filtrada usando Gabella e interpolada en la carpeta plot_dir para el barrido sweep.

    Input:  var = 'DB_DBZ' o 'DB_VEL' 
            radar_dict = diccionario decodificado de IRIS_fn (ver IRIS_decode)
            plot_dir = directorio de destino de las imagenes (srt)
            IRIS_fn = nombre del archivo IRIS (str)
            sweep = # de barrida (int)

    Output: gráficas reflectividad_clean_%(fn)s_sweep_%(sw)s.png o velocidad_radial_clean_%(fn)s_sweep_%(sw)s.png
            en la carpeta plot_dir segun var = 'DB_DBZ' o 'DB_VEL' respectivamente
    '''

    if var == 'DB_DBZ' or var == 'DB_VEL':
        pass
    else:
        print('variable var inexistente: %s' %var)
        return
    
    # read data
    radii, theta, phi = calc_sph_components(radar_dict, var=var, sweep=sweep)
    lat = radar_dict['ingest_header']['ingest_configuration']['latitude_radar']
    lon = radar_dict['ingest_header']['ingest_configuration']['longitude_radar']
    site_height = radar_dict['ingest_header']['ingest_configuration']['height_site'] #en metros
    radar_height = radar_dict['ingest_header']['ingest_configuration']['height_radar'] #en metros

    #leer, filtrar e interpolar datos de variable var y barrida sweep
    ma_clean = clean_data(radar_dict, var=var, sweep=sweep)

    fig = plt.figure(figsize=(10,8))
    cgax, pm = wrl.vis.plot_ppi(ma_clean, r=radii, rf=1e3, az=theta, elev=phi, fig=fig, proj='cg', site=(lon, lat, site_height + radar_height))
    caax = cgax.parasites[0]
    if var == 'DB_DBZ':
        t = plt.title('reflectividad para %(fn)s barrido %(sw)s - clean' % dict(fn=IRIS_fn, sw=sweep))
    else:
        t = plt.title('velocidad radial para %(fn)s barrido %(sw)s - clean' % dict(fn=IRIS_fn, sw=sweep))
    t.set_y(1.1)
    cbar = plt.gcf().colorbar(pm, pad=0.075)
    caax.set_xlabel('hacia el oriente [km]')
    caax.set_ylabel('hacia el horte [km]')
    plt.text(1.0, 1.05, 'azimutal', transform=caax.transAxes, va='bottom',
        ha='right')
    if var == 'DB_DBZ':
        cbar.set_label('reflectividad [dBZ]')
        plot_name = "reflectividad_clean_%(fn)s_sweep_%(sw)s.png" \
            % dict(fn=IRIS_fn, sw=sweep)
    else:
        cbar.set_label('velocidad radial [m/s]')
        plot_name = "velocidad_radial_clean_%(fn)s_sweep_%(sw)s.png" \
            % dict(fn=IRIS_fn, sw=sweep)
    plt.savefig(plot_dir + plot_name, dpi=300, papertype='letter')
    plt.close()
    
    return ma_clean
    
    
def main():
    
    print('IRIS_decoder.py inició')

    #datos de entrada
    RAW_dir = './data/' #carpeta para descargar los archivos de radar RAW
    dec_dir = './decoded/' #carpeta para escribir los diccionarios decodificados de radar
    plot_dir = './plots/' #carpeta para las gráficas de los datos decodificados de radar
#    FAC_url = 'https://www.simfac.mil.co/imag/tempo/MC/radar/' #url de los archivos de radar
    FAC_url = 'https://www.simfac.mil.co/imag/RADAR/raw/' #06082019 cambio de la url por la nueva
    ini_date = datetime(2017, 6, 8, 1) # fecha inicial ejecución (dentro de esta fecha debn existir archivos de la FAC_URL)
    delta = 1 #(int) en horas, ventana de asimilación
    
    #verificar existencia de carpetas
    if not os.path.isdir(RAW_dir):
        os.makedirs(RAW_dir)
    if not os.path.isdir(dec_dir):
        os.makedirs(dec_dir)
    if not os.path.isdir(plot_dir):
        os.makedirs(plot_dir)

    #ventana de asimilación
    start_date = ini_date - timedelta(hours=delta)
    end_date = ini_date + timedelta(hours=delta)
    
    #descargar archivos RAW
    IRIS_download(FAC_url, start_date, end_date, dest_dir=RAW_dir)

    #listar archivos RAW 
    IRIS_fn = list_dir_dat(RAW_dir, start_date, end_date)

    if len(IRIS)_fn == 0:
        print('Ningún archivo de radar RAW entre las fechas %s y %s en la carpeta %s' % (start_date, end_date, RAW_dir))
        print('Finalizando IRIS_decoder')
        return

    for i in range(0, len(IRIS_fn)):
        #decodificar y guardar archivo para lectura humana
        IRIS_decode_and_save(IRIS_fn[i], IRIS_dir=RAW_dir, dest_dir=dec_dir)
        #decodificar archivo
        radar_dict = IRIS_decode(IRIS_fn[i], IRIS_dir=RAW_dir)
        max_sweep =  radar_dict['ingest_header']['ingest_configuration']['number_sweeps_completed']
        #imprimir información general en pantalla
        print_general_data(radar_dict)
        for sw in range(1,max_sweep + 1):
            print('barrido %s' % sw)
            #imprimir información específica en pantalla
            print_sweep_spec_data(radar_dict, sweep=sw)
            DBZ = radar_dict['data'][sw]['sweep_data']['DB_DBZ']['data']
            VEL = radar_dict['data'][sw]['sweep_data']['DB_VEL']['data']
            print('\tgraficando reflectividad y velocidad radial (RAW) de %s, barrida %s' % (IRIS_fn[i], sw))
            plot_DBZ_and_VEL(DBZ, VEL, IRIS_fn[i], plot_dir=plot_dir, sweep=sw) #raw 2d
            print('\tgraficando reflectividad y velocidad radial clutter de %s, barrida %s' % (IRIS_fn[i], sw))
            plot_clutter(IRIS_fn[i], radar_dict, var='DB_DBZ', plot_dir=plot_dir, sweep=sw) 
            plot_clutter(IRIS_fn[i], radar_dict, var='DB_VEL', plot_dir=plot_dir, sweep=sw) 
            print('\tgraficando reflectividad y velocidad radial clean de %s, barrida %s' % (IRIS_fn[i], sw))
            plot_clean_data(IRIS_fn[i], radar_dict, var='DB_DBZ', plot_dir=plot_dir, sweep=sw) 
            plot_clean_data(IRIS_fn[i], radar_dict, var='DB_VEL', plot_dir=plot_dir, sweep=sw) 
            print('\tgraficando reflectividad y velocidad radial esféricas de %s, barrida %s' % (IRIS_fn[i], sw))
            plot_sph_components(IRIS_fn[i], radar_dict, var='DB_DBZ', plot_dir=plot_dir, sweep=sw) 
            plot_sph_components(IRIS_fn[i], radar_dict, var='DB_VEL', plot_dir=plot_dir, sweep=sw)
            print('\tgraficando extras de %s' % IRIS_fn[i])
            plot_extra_data(IRIS_fn[i], radar_dict, var='DB_DBZ', plot_dir=plot_dir, sweep=sw)
            plot_extra_data(IRIS_fn[i], radar_dict, var='DB_VEL', plot_dir=plot_dir, sweep=sw)
    
    print('IRIS_decoder.py terminó')
    return

if __name__ == "__main__":
  main()
