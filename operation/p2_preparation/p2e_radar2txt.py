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
Leer reflectividad y velocidad radial decodificada filtrada e interpolada de los archivos de radar RAW de la carpeta RAW_dir entre las fecha start_date y end_date. 

Transformar de coordenadas esféricas (r, theta, phi) a coordenadas cartesianas (lat, lon, alt) proyectadas en el sitio del radar.

Interpolar la longitud, latitud, altitud, reflectividad y velocidad radial a la resolución del modelo (9kmx9km).

Calcular el error de la reflectividad y la velocidad radial (http://www2.mmm.ucar.edu/wrf/users/tutorial/200807/VAR/WRFVAR_RADAR_22JUL08.pdf)

Escribir la línea de datos en formato FORTRAN para el Header del archivo txt (nombre, lat del radar, lon del radar, altura del radar,
 fecha, # de registros totales, # de alturas totales)

Escribir la línea de datos en formato FORTRAN comunes para una medición de radar (fecha, lat de la medición, lon de la medición, altura del radar,
 # de alturas)

Escribir la línea de datos en formato FORTRAN para una medición de radar (altura de medición, reflectividad, 
control de calidad de la reflectividad, error de la reflectividad, velocidad radial, control de calidad de la velocidad radial 
y error de la velocidad radial) de una elevación, latitud y longitud específicas.

Escribir el archivo obs_radar.txt con las observaciones de reflectividad y velocidad radial en formato FORTRAN 
de los radares de la lista IRIS_fn dentro de la fecha [<datetime>-<timedelta>, <datetime>+<timedelta>]
'''

import logging 
import matplotlib.pyplot as plt
import numpy as np
import os
import wradlib as wrl

from datetime import datetime, timedelta
from mpl_toolkits import mplot3d
from pprint import pprint

def list_dir_dat(dir_path, start_date, end_date):
    ''' Listar los archivos .RAW de un directorio entre la fecha start_date y end_date. 

    Input:  dir_path = diccionario de archivos IRIS RAW 
            start_date = fecha inicial de ventana de asimilación en hora local (datetime.datetime)
            end_date = fecha final de ventana de asimilación en hora local (datetime.datetime)

    Output: lista de nombres de archivos IRIS RAW en la carpeta dir_path
    '''

    files = []
    # r=root, d=directories, f = files
    for r, d, f in os.walk(dir_path):
        for file in f:
            if '.RAW' in file:
                date_st = file[-20:-8] #extraer fecha de archivo: COR170608000002.RAWF1FM --> 170608000002 
                date = datetime.strptime(date_st, '%y%m%d%H%M%S')
                if date > start_date and date < end_date:
                    files.append(file)

    return files

def IRIS_decode(IRIS_fn, IRIS_dir='./'):
    ''' Decodificar el archivo IRIS_fn usando wradlib y retornar el diccionario decodificado.

    Input:  IRIS_dir = ruta del archivo IRIS a decodificar 
            IRIS_fn = nombre del archivo IRIS a decodificar

    Output: archivo IRIS decodificado en un diccionario
    '''
    logging.info('decodificando %s' % IRIS_dir + IRIS_fn)
    return wrl.io.iris.read_iris(IRIS_dir + IRIS_fn, loaddata = {'moment': ['DB_DBZ', 'DB_VEL']}, rawdata=False)

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
        logging.warning('variable var inexistente: %s' %var)
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

def calc_sph_3D(radar_dict, var='DB_DBZ'):
    ''' Calcular las componentes esféricas de var (contenidas en radar_dict) para todas las barridas
        con magnitudes físicas (radii = m, theta = grados)

    Input:  radar_dict = diccionario decodificado de IRIS_fn (ver IRIS_decode)
            var = 'DB_DBZ' o 'DB_VEL'
            
    Output: arreglos radii, theta y phi
    '''    
    theta = []
    phi = []
    max_sweep =  radar_dict['ingest_header']['ingest_configuration']['number_sweeps_completed']

    #calcular distancia radial en metros
    dist_first_bin = radar_dict['ingest_header']['task_configuration']['task_range_info']['range_first_bin']/100.0 # en metros
    dist_last_bin = radar_dict['ingest_header']['task_configuration']['task_range_info']['range_last_bin']/100.0 # en metros
    bins_step = radar_dict['ingest_header']['task_configuration']['task_range_info']['step_output_bins']/100.0 # en metros

    radii = np.arange(dist_first_bin + bins_step/2.0, dist_last_bin + bins_step/2.0, bins_step) #ubicado en el centroide del bin

    #promediar azi_start y azi_stop para calcular theta en grados
    azi_start = radar_dict['data'][1]['sweep_data'][var]['azi_start']
    azi_stop = radar_dict['data'][1]['sweep_data'][var]['azi_stop']
    #corrección para salto entre 0 y 2pi para theta
    for ang in np.arange(0, len(azi_start)):
        if azi_start[ang] - azi_stop [ang] < 1e-8:
            theta.append((azi_start[ang] + azi_stop [ang])/2.0)
        else:
            theta.append(((azi_start[ang] - 360) + azi_stop [ang])/2.0)
    theta = np.array(theta) #en grados

    #extraer angulo de elevación phi de todas las barridas
    for ang in np.arange(1, max_sweep + 1):
        #promediar ele_start y ele_stop para calcular phi en grados
        ele_start = radar_dict['data'][ang]['sweep_data'][var]['ele_start'][0]
        ele_stop = radar_dict['data'][ang]['sweep_data'][var]['ele_stop'][0]
        phi.append((ele_start + ele_stop)/2.0)
    phi = np.array(phi) #en grados

    return radii, theta, phi

def calc_cart_coordinates(radar_dict, var='DB_DBZ'):
    ''' Calcular las coordenadas cartesianas espaciales de la variable var de todas las barridas.

    Input:  var = 'DB_DBZ' o 'DB_VEL' 
            radar_dict = diccionario decodificado de IRIS_fn (ver IRIS_decode)

    Output: lonlatalt[..., 0], lonlatalt[..., 1], lonlatalt[..., 2], respectivamente: londitud, latitud y altura en metros.
    '''

    if var == 'DB_DBZ' or var == 'DB_VEL':
        pass
    else:
        logging.warning('variable var inexistente: %s' %var)
        return
    #read data
    lat = radar_dict['ingest_header']['ingest_configuration']['latitude_radar']
    lon = radar_dict['ingest_header']['ingest_configuration']['longitude_radar']
    site_height = radar_dict['ingest_header']['ingest_configuration']['height_site'] #en metros
    radar_height = radar_dict['ingest_header']['ingest_configuration']['height_radar'] #en metros
    site = (lon, lat, site_height + radar_height)
    #extraer y calcular variables esféricas espaciales con unidades físicas
    _radii, _theta, _phi = calc_sph_3D(radar_dict, var)
    #crear meshgrid de puntos en esféricas
    radii, theta, phi = np.meshgrid(_radii, _theta, _phi, indexing='ij')
    #transformar coordenadas usando georef
    lonlatalt = wrl.georef.spherical_to_proj(radii, theta, phi, site)
    return lonlatalt[..., 0], lonlatalt[..., 1], lonlatalt[..., 2]

def calc_err_DBZ(DBZ, i, j, k):
    ''' Calcular el error de la variable DBZ en el punto i, j, k
        basado en la desviación estándar de una rejilla 3x3 sobre el plano i, j.
        http://www2.mmm.ucar.edu/wrf/users/tutorial/200807/VAR/WRFVAR_RADAR_22JUL08.pdf

    Input:  DBZ = archivo de reflectividades MaskedArray producto de clean_data
            i = índice del arreglo, va hasta DBZ.shape[0] (int)
            j = índice del arreglo, va hasta DBZ.shape[1] (int)
            k = índice del arreglo, va hasta DBZ.shape[2] (int)

    Output: np.std(lst), desviación estándar del punto y sus primeros vecinos.
    '''

    lst = np.ma.append(DBZ[i, j, k], DBZ[i, j-1, k])
    lst = np.ma.append(lst, DBZ[i-1, j-1, k])
    lst = np.ma.append(lst, DBZ[i-1, j, k])
    if i < DBZ.shape[0] - 1:
        lst = np.ma.append(lst, DBZ[i+1, j-1, k])
        lst = np.ma.append(lst, DBZ[i+1, j, k])
    if j < DBZ.shape[1] - 1:
        lst = np.ma.append(lst, DBZ[i, j+1, k])
        lst = np.ma.append(lst, DBZ[i-1, j+1, k])
    if i < DBZ.shape[0] - 1 and j < DBZ.shape[1] - 1:
        lst = np.ma.append(lst, DBZ[i+1, j+1, k])
    return np.std(lst)

def calc_err_VEL(VEL, i, j, k):
    ''' Calcular el error de la variable DBZ en el punto i, j, k
        basado el 10% de la medida.
        http://www2.mmm.ucar.edu/wrf/users/tutorial/200807/VAR/WRFVAR_RADAR_22JUL08.pdf

    Input:  VEL = archivo de velocidades radiales MaskedArray producto de interp_data
            i = índice del arreglo, va hasta VEL.shape[0] (int)
            j = índice del arreglo, va hasta VEL.shape[1] (int)
            k = índice del arreglo, va hasta VEL.shape[2] (int)

    Output: np.abs(VEL[i, j, k])/10.0
    '''

    return np.abs(VEL[i, j, k])/10.0
    
def clean_data_3D(radar_dict):
    ''' limpiar las variables reflectividad y velocidad radial filtrada usando Gabella e interpolada para todos los barridos.
        Usando recursivamente clean_data.

    Input:  radar_dict = diccionario decodificado de IRIS_fn (ver IRIS_decode)

    Output: MaskedArray DBZ_3D y VEL_3D con forma (radios, theta, phi)
    '''
    
    max_sweep =  radar_dict['ingest_header']['ingest_configuration']['number_sweeps_completed']
    for sw in np.arange(1, max_sweep + 1):
        #leer datos filtrados e interpolados de todas las barridas
        DBZ = clean_data(radar_dict, var='DB_DBZ', sweep=sw)
        VEL = clean_data(radar_dict, var='DB_VEL', sweep=sw)
        #transponer de (theta, r) a (r, theta) para luego hacer (r, theta, phi)
        DBZ = DBZ.transpose()
        VEL = VEL.transpose()
        #incrementar dimension del arreglo
        T1 = DBZ[..., np.newaxis]
        T2 = VEL[..., np.newaxis]
        #añadir los archivos de datos de esta barrida al masked numpy array (r, theta, phi)
        if sw == 1:
            DBZ_3D = T1
            VEL_3D = T2
        else:
            DBZ_3D = np.ma.concatenate([DBZ_3D, T1], axis=2) # el eje 2 es la tercera dimensión
            VEL_3D = np.ma.concatenate([VEL_3D, T2], axis=2) # el eje 2 es la tercera dimensión
    return DBZ_3D, VEL_3D

def count_total_data(DBZ_3D, VEL_3D):
    ''' Contar el número total de datos posibles para asimilar de los arreglos DBZ_3D y VEL_3D.
        Criterio: que el dato sea válido tanto en DBZ_3D como en VEL_3D.

    Input:  DBZ_3D = np.ma.MaskedArray de reflectividades creado por interp_data
            VEL_3D = np.ma.MaskedArray de velocidades radiales creado por interp_data

    Output: num_reg_tot, el número total de datos posibles para asimilación
    '''
    
    num_reg_tot = 0
    #for k in range(0, 2):
    for i in np.arange(0, DBZ_3D.shape[0]):
        #si el dato [i, j, k] en la mask es valido (mask = False) entonces cuéntelo
        for j in np.arange(0, DBZ_3D.shape[1]): 
            #contar los puntos i,j que tengan algún nivel k válido
            if count_levels(DBZ_3D, VEL_3D, i, j) > 0:
                num_reg_tot += 1
                   
    return num_reg_tot


def count_levels(DBZ_3D, VEL_3D, i, j):
    ''' Contar el número de niveles validos de DBZ_3D y VEL_3D para el punto i ,j.
        Criterio: que el dato sea válido tanto en DBZ_3D como en VEL_3D.

    Input:  DBZ_3D = np.ma.MaskedArray de reflectividades creado por interp_data
            VEL_3D = np.ma.MaskedArray de velocidades radiales creado por interp_data
            i = índice del arreglo, va hasta DBZ.shape[0] (int)
            j = índice del arreglo, va hasta DBZ.shape[1] (int)

    Output: num_reg_tot, el número total de datos posibles para asimilación
    '''
    lev = 0
    #for k in np.arange(0, 2): #cantidad de elevaciones
    for k in np.arange(0, DBZ_3D.shape[2]): #cantidad de elevaciones
        #si el dato [i, j, k] en la mask es valido (mask = False) entonces cuéntelo
        #si el punto i,j,k tiene datos numéricos válidos
        if DBZ_3D[i, j, k] is not np.ma.masked and VEL_3D[i, j, k] is not np.ma.masked:
            lev += 1
    return lev

def create_output_file(outfile, out_dir='./', nrad=1):
    ''' crear el archivo de salida de nombre outfile en la carpeta out_dir

    Input:  outfile = nombre del archivo de salida txt (str)
            out_dir = carpeta de destino del archivos txt (str)
            nrad = # total de radares asimilados

    Output: archivo de salida de nombre outfile en la carpeta out_dir 
    '''

    fmt = '%14s%3i'
    with open(out_dir + outfile, mode='w', encoding='ascii') as f: 
        f.write(fmt % ('TOTAL NUMBER =', nrad))
        f.write('\n')
        f.write('%s' % ('#-----------------#'))
        f.write('\n')
    return

def write_header(outfile, radar_name, lon0, lat0, elv0, date, np, max_levs, out_dir='./'):
    ''' Escribir el header del archivo de salida de nombre outfile en la carpeta out_dir

    Input:  outfile = nombre del archivo de salida (str)
            out_dir = carpeta de destino de archivo de salida txt (str)
            radar_name = nombre del radar (str)
            lon0 = lontigud del radar (float ,grados)
            lat0 = latitud del radar (float, grados)
            elv0 = elevación del radar (float, msnm)
            date = fecha de ingesta de datos en hora local (datetime.datetime)
            np = # total de medidas asimiladas para el radar (int resultado de count_total_data)
            max_levs = # total de elevaciones (int, ver max_sweep)  
            

    Output: header del archivo de salida de nombre outfile en la carpeta out_dir
    '''

    # definir el formato del header
    fmt = '%5s%2s%12s%8.3f%2s%8.3f%2s%8.1f%2s%19s%6i%6i' #(a5,2x,a12,2(f8.3,2x),f8.1,2x,a19,2i6)
    h_sp = ''
    #pasar fecha a string con formato 
    date_s = date.strftime('%Y-%m-%d_%H:%M:%S')
    with open(out_dir + outfile, mode='a', encoding='ascii') as f:
        f.write('\n')
        f.write(fmt % ('RADAR', h_sp, radar_name, lon0, h_sp, lat0, h_sp, elv0, h_sp, date_s, np, max_levs))
        f.write('\n')
        f.write('%s' % (
            '#-------------------------------------------------------------------------------#'))
        f.write('\n')
        f.write('\n')
    return

def write_obs_line(infile, elv, rf_data, rf_qc, rf_err, rv_data, rv_qc, rv_err, h_sp=''):
    ''' Escribir los datos específicos de reflectividad y velocidad radial para el punto i,j,k en el archivo abierto infile

    Input:  infile = handler del archivo abierto por write_data_xy
            elv = elevación de la medición (float, msnm)
            rf_data = arreglo tridimensional de reflectividades (ver interp_data)
            rf_qc = flag de control de calidad de la reflectividad = 0 aceptar valor
            rf_err = error de la reflectividad (float, ver calc_err_DBZ) 
            rv_data = arreglo tridimensional de velocidades radiales (ver interp_data)
            rv_qc = flag de control de calidad de la velocidad radial = 0 aceptar valor
            rv_err = error de la velocidad radial (float, ver calc_err_VEL)  
            
    Output: datos específicos de reflectividad y velocidad radial para el punto i,j,k en el archivo abierto infile
    '''

    fmt_line = '%3s%12.1f%12.3f%4i%12.3f%2s%12.3f%4i%12.3f%2s' #(3x,f12.1,2(f12.3,i4,f12.3,2x))
    infile.write(fmt_line % (h_sp, elv, rv_data, rv_qc, rv_err, h_sp, rf_data, rf_qc, rf_err, h_sp))
    infile.write('\n')

def write_data_xy(outfile, date, elv0, lat, lon, elv, rf_data, rv_data, out_dir='./'):
    ''' Escribir los datos comunes de un punto xy (i,j) en el archivo de salida de nombre outfile en la carpeta out_dir

    Input:  outfile = nombre del archivo de salida (str)
            out_dir = carpeta de destino de archivo de salida txt (str)
            date = fecha de la medición del radar en hora local (datetime.datetime)
            lon = lontigud de la medición (float, grados, ver interp_data)
            lat = latitud de la medición (float, grados, ver interp_data)
            elv = elevación de la medición (float, msnm, ver interp_data)
            elv0 = elevación del radar (float, msnm)
            rf_data = arreglo tridimensional de reflectividades (ver interp_data)
            rv_data = arreglo tridimensional de velocidades radiales (ver interp_data)  
            
    Output: escribir los datos comunes del radar en el archivo outfile
    '''

    fmt = '%12s%3s%19s%2s%12.3f%2s%12.3f%2s%8.1f%2s%6i' #(a12,3x,a19,2x,2(f12.3,2x),f8.1,2x,i6)
    h_sp = ''
    #pasar fecha a string con formato 
    date_s = date.strftime('%Y-%m-%d_%X')
    with open(out_dir + outfile, mode='a', encoding='ascii') as f:
        # ciclo sobre puntos horizontales
        for i in np.arange(0, rf_data.shape[0]):
            for j in np.arange(0, rf_data.shape[1]):
                #contar elevaciones válidas
                levs = count_levels(rf_data, rv_data, i, j)
                if levs > 0:    
                    #escribir en archivo si hay un dato válido tanto en DBZ como en VEL
                    f.write(fmt % ('FM-128 RADAR', h_sp, date_s, h_sp, float(lat[i, j]), h_sp, float(lon[i, j]), h_sp, int(elv0), h_sp, int(levs)))
                    f.write('\n')
                    # ciclo sobre elevaciones verticales
                    for k in np.arange(0, rf_data.shape[2]): 
                        #si el punto i,j,k tiene datos numéricos válidos tanto en DBZ como en VEL
                        if rf_data[i, j, k] is not np.ma.masked and rv_data[i, j, k] is not np.ma.masked:
                            # Escribir línea de medición a una elevación dada
                            write_obs_line(f, elv[i,j,k], rf_data[i,j,k], 0, calc_err_DBZ(rf_data,i,j,k), rv_data[i,j,k], 0, calc_err_VEL(rv_data,i,j,k), h_sp=h_sp)
    return

def interp_data(lon, lat, alt, DBZ_3D, VEL_3D):
    ''' Interpolar la longitud, latitud, altura, reflectividad y velocidad radial a la resolución del modelo 9kmx9km

    Input: lon = arreglo tridimensional de longitudes (ver calc_cart_coordinates)
           lat = arreglo tridimensional de latitudes (ver calc_cart_coordinates)
           alt = arreglo tridimensional de alturas (ver calc_cart_coordinates)
           DBZ_3D = arreglo tridimensional de reflectividades (ver clean_data_3D)
           VEL_3D = arreglo tridimensional de velocidades radiales (ver clean_data_3D)

    Output: arreglos interpolados de longitud y latitud (bidimensionales) y 
            arreglos interpolados de alturas, reflectividades y velocidades radiales (tridimensionales)
    '''
    #promediar la longitud y la latitud sobre el eje z
    lon_mean = np.mean(lon, axis=2) #el eje 2 es la tercera dimensión
    lat_mean = np.mean(lat, axis=2) #el eje 2 es la tercera dimensión

    #conversion 
    #1 grado de latitud son 111,325 Kilometros
    #1 grado de longitud depende de la latitud = coseno(latitud, en radianes) * 111,325 Kilometros

    #leer longitud mínima, longitud máxima en grados
    lon_min = np.amin(lon_mean)
    lon_max = np.amax(lon_mean)
    #leer latitud mínima, latitud máxima en grados
    lat_min = np.amin(lat_mean)
    lat_max = np.amax(lat_mean)

    #9km en longitud son en grados
    km_lon = 9.0/111.325/np.cos(np.radians(lat_min+lat_max)/2.0)
    #9km latitud son en grados 
    km_lat = 9.0/111.325 

    #crear arreglo rectangular destino
    lon_int = np.arange(lon_min, lon_max, km_lon) 
    lat_int = np.arange(lat_min, lat_max, km_lat)

    #Pasar de un arreglo 664x360 a la resolución del modelo (9kmx9km)

    #promediar vairables si se encuentran entre el rectángulo:
    # (lon_int,lat_int+9km) --- (lon_int+9km, lat_int+9km)
    #         |                             |
    #  (lon_int,lat_int)    ---   (lon_int+9km, lat_int)

    #crear arreglos de destino de longitud y latitud
    new_lon = np.zeros((len(lon_int)-1, len(lat_int)-1))
    new_lat = np.zeros((len(lon_int)-1, len(lat_int)-1))
    #crear plano resultado de longitud y latitud
    for ix in np.arange(0,len(lon_int)-1):
        for iy in np.arange(0,len(lat_int)-1):
            # promediar para obtener la nueva longitud
            new_lon[ix, iy] = (lon_int[ix]+lon_int[ix+1])/2.0
            # promediar para obtener la nueva latitud
            new_lat[ix, iy] = (lat_int[iy]+lat_int[iy+1])/2.0

    #crear arreglos de destino de alturas, reflectividades y velocidades radiales
    new_alt = np.zeros((len(lon_int)-1, len(lat_int)-1, alt.shape[2]))
    new_DBZ = np.zeros((len(lon_int)-1, len(lat_int)-1, DBZ_3D.shape[2]))
    new_VEL = np.zeros((len(lon_int)-1, len(lat_int)-1, VEL_3D.shape[2]))
    #ciclo sobre elevaciones
    for k in np.arange(0, alt.shape[2]):

        #leer datos para un nivel k
        DBZ = np.ma.squeeze(DBZ_3D[..., k])
        VEL = np.ma.squeeze(VEL_3D[..., k])
        lon1 = np.squeeze(lon[..., k])
        lat1 = np.squeeze(lat[..., k])    
        alt1 = np.squeeze(alt[..., k])
        
        #ciclo sobre el plano xy
        for ix in np.arange(0,len(lon_int)-1):
            # (a) seleccionar índices del arreglo lon[x,y] con x entre lon_int[ix] y lon_int[ix+1]
            ind_lon = np.logical_and(lon1 >= lon_int[ix], lon1 < lon_int[ix+1])
            
            for iy in np.arange(0,len(lat_int)-1):
                # (b) seleccionar índices del arreglo lat[x,y] con y entre lat_int[iy] y lat_int[iy+1]
                ind_lat = np.logical_and(lat1 >= lat_int[iy], lat1 < lat_int[iy+1])

                # crear arreglo temporal de alturas con índices tanto en (a) como en (b)
                temp_alt_xy = alt1[np.logical_and(ind_lon, ind_lat)]
                
                temp_DBZ_xy = DBZ[np.logical_and(ind_lon, ind_lat)]

                temp_VEL_xy = VEL[np.logical_and(ind_lon, ind_lat)]
                
                #condicional sobre alturas válidas                
                if (temp_VEL_xy.mean() is not np.ma.masked) and (temp_DBZ_xy.mean() is not np.ma.masked) and (len(temp_alt_xy) > 0):
                    # promediar parche de alturas
                    new_alt[ix, iy, k] = temp_alt_xy.mean()
                    # promediar reflectividades
                    new_DBZ[ix, iy, k] = temp_DBZ_xy.mean()
                    # promediar velocidades radiales
                    new_VEL[ix, iy, k] = temp_VEL_xy.mean()  
                else:
                    #fillvalue
                    new_alt[ix, iy, k] = 999999
                    new_DBZ[ix, iy, k] = 999999
                    new_VEL[ix, iy, k] = 999999

    #Transformar a masked array
    new_alt = np.ma.masked_equal(new_alt, 999999)
    new_DBZ = np.ma.masked_equal(new_DBZ, 999999)
    new_VEL = np.ma.masked_equal(new_VEL, 999999)
     
    '''
    #(developer) graficar los datos interpolados para los niveles k 
    for k in np.arange(0, alt.shape[2]):
        print('k=%s' % k)

        fig = plt.figure()
        ax = fig.add_subplot(231)
        ax.imshow(new_lon, aspect='auto', cmap=plt.cm.gray, interpolation='nearest')
        ax = fig.add_subplot(232)
        ax.imshow(new_lat, aspect='auto', cmap=plt.cm.gray, interpolation='nearest')
        ax = fig.add_subplot(233)
        ax.imshow(new_alt[..., k], aspect='auto', cmap=plt.cm.gray, interpolation='nearest')
        ax = fig.add_subplot(234)
        ax.imshow(new_DBZ[..., k], aspect='auto', interpolation='nearest')
        ax = fig.add_subplot(235)
        ax.imshow(new_VEL[..., k], aspect='auto', interpolation='nearest')
        plt.show()
    '''
            
    return new_lon, new_lat, new_alt, new_DBZ, new_VEL

def plot_xyz(lon, lat, alt):
    #(developer) funcion para graficar el cono de datos geoespaciales de diversos niveles k
    '''
    p_i = 0
    p_j = 0
    DBZ = np.ma.squeeze(DBZ_3D[p_i, p_j, :])
    VEL = np.ma.squeeze(VEL_3D[p_i, p_j, :])
    lon1 = np.squeeze(lon[p_i, p_j, :])
    lat1 = np.squeeze(lat[p_i, p_j, :])    
    alt1 = np.squeeze(alt[p_i, p_j, :])
    lev1 = count_levels(DBZ_3D, VEL_3D, p_i, p_j)
    
    #print('lon1, lat1, alt1')
    #pprint(lon1)
    #pprint(lat1)
    #pprint(alt1)
    #print('DBZ')
    #pprint(DBZ)
    #print('VEL')
    #pprint(VEL)
    #print('lev1: %s' % lev1)

    #print('\n')
    print('DBZ.shape: ', DBZ.shape)
    print('VEL.shape: ', VEL.shape)
    print('lon1.shape: ', lon1.shape)
    print('lat1.shape: ', lat1.shape)
    print('alt1.shape: ', alt1.shape)

    print('DBZ.count(): ', DBZ.count()) #(r, theta, phi) en índices
    print('VEL.count(): ', VEL.count()) #(r, theta, phi) en índices
    '''

    fig = plt.figure()
    ax = plt.axes(projection='3d')

    for j in np.arange(0, lon.shape[1], 5):
        for k in np.arange(0, 9, 3):
            lon1 = np.squeeze(lon[::50, j, k]) 
            lat1 = np.squeeze(lat[::50, j, k])    
            alt1 = np.squeeze(alt[::50, j, k]) 
        
            ax.plot3D(lon1, lat1, alt1, marker='+')
    
    plot_name = 'lonlatalt_test.png'
    plt.savefig(plot_name, dpi=300, papertype='letter')
    plt.show()
    plt.close()

    return   


def radar2txt(settings): 
    
    logging.info('#### Descargando los datos de radar RAW') 

    #datos de entrada
    RAW_dir = os.path.join(settings['globals']['data'], 'radar', 'RAW/')

    if not os.path.isdir(RAW_dir):
        logging.warning('RAW_dir no es una carpeta, revisar %s y proceso de descarga p1e_radar en settings.ini' %RAW_dir)
        return

    delta = int(int(settings['assim']['time_window'])/2.0)
    
    # fecha inicial UTC
    ini_date = settings['globals']['start_date'] 

    #ventana de asimilación
    start_date = ini_date - timedelta(hours=delta)
    end_date = ini_date + timedelta(hours=delta)

    #crear directorio para archivo de salida
    out_dir = os.path.join(settings['globals']['data'], 'radar', 'wrfda/')
    if not os.path.isdir(out_dir):
        os.makedirs(out_dir)

    #listar archivos RAW 
    IRIS_fn = list_dir_dat(RAW_dir, start_date, end_date)
    
    #verificar cantidad de archivos a leer
    if len(IRIS_fn) > 0:
        #nombre del archivo de salida
        out_fn = 'obs_radar.txt'
        logging.info('Ruta de archivo traducido: '+out_dir+out_fn)
        #crear archivo de salida para un radar
        create_output_file(out_fn, out_dir=out_dir, nrad=len(IRIS_fn))
    else:
        logging.warning('No hay archivos RAW para traducir en el intervalo %s, %s en el directorio %s' %(start_date, end_date, RAW_dir))
        return

    #contador para archivos fallidos
    failed_files = 0
    #por cada archivo de radar válido (ciclo sobre radares)
    for fn in np.arange(0,len(IRIS_fn)):

        #seleccionar un solo archivo de radar
        logging.info('Procesando archivo %s' % IRIS_fn[fn])

        #leer diccionario de un archivo RAW
        try:
            radar_dict = IRIS_decode(IRIS_fn[fn], IRIS_dir=RAW_dir)
        except Exception as e: 
            logging.warning('Imposible decodificar %s' % IRIS_fn[fn])
            logging.warning(e)
            failed_files += 1
            continue

        #leer reflectividad y velocidad radial filtrada e interpolada para todas las barridas
        try:
            logging.info('Limpiando y filtrando (clutter) archivo %s' % IRIS_fn[fn])
            DBZ_3D, VEL_3D = clean_data_3D(radar_dict)
        except Exception as e: 
            logging.warning('Imposible limpiar datos %s' % IRIS_fn[fn])
            logging.warning(e)
            failed_files += 1
            continue

        #transformar coordenadas esféricas a coordenadas cartesianas ubicadas en el sitio del radar
        try:
            logging.info('Proyectando a las coordenadas del radar %s' % IRIS_fn[fn])
            lon, lat, alt = calc_cart_coordinates(radar_dict, var='DB_DBZ')
        except Exception as e: 
            logging.warning('Imposible proyectar coordenadas %s' % IRIS_fn[fn])
            logging.warning(e)
            failed_files += 1
            continue

        #plot_xyz(lon, lat, alt)

        #Interpolar los arreglos lon, lat, alt, DBZ_3D y VEL_3D a una rejilla 9kmx9km 
        try:
            logging.info('Interpolando a la resolución del modelo %s' % IRIS_fn[fn])
            new_lon, new_lat, alt_3D, new_DBZ_3D, new_VEL_3D = interp_data(lon, lat, alt, DBZ_3D, VEL_3D)
        except Exception as e: 
            logging.warning('Imposible interpolar %s' % IRIS_fn[fn])
            logging.warning(e)
            failed_files += 1
            continue
        
        
        logging.info('Escribiendo datos al archivo obs_radar.txt')
        # extraer de diccionario las variables de interés para el header
        site_name = IRIS_fn[fn][:3]
        lat_rad = radar_dict['ingest_header']['ingest_configuration']['latitude_radar']
        lon_rad = radar_dict['ingest_header']['ingest_configuration']['longitude_radar']
        site_height = radar_dict['ingest_header']['ingest_configuration']['height_site'] #en metros
        radar_height = radar_dict['ingest_header']['ingest_configuration']['height_radar'] #en metros
        file_time = radar_dict['product_hdr']['product_configuration']['sweep_ingest_time']
        elv_rad = site_height + radar_height

        #contar número total de registros válidos
        num_reg_tot = count_total_data(new_DBZ_3D, new_VEL_3D)
        
        #escribir header, el cual cambia según el radar
        write_header(out_fn, site_name, lon_rad, lat_rad, elv_rad, file_time, num_reg_tot, new_DBZ_3D.shape[2], out_dir=out_dir)
    
        #escribir datos para el plano xy y las alturas válidas
        write_data_xy(out_fn, file_time, elv_rad, new_lat, new_lon, alt_3D, new_DBZ_3D, new_VEL_3D, out_dir=out_dir)

        #reportar en log la terminación del proceso
        logging.info('Terminado de procesar el archivo %s' % IRIS_fn[fn])

    #verificar que minimo un archivo haya sido traducido y escrito
    if failed_files==len(IRIS_fn):
        logging.warning('No se pudo traducir ni interpolar ningún archivo RAW')
        return

    #reescribir primera línea del archivo de salida: 
    out_fn_2 = 'obs_radar_clean.txt'
    logging.info('archivos fallidos: %s' % failed_files)

    logging.info('Creando obs_radar_clean.txt')
    with open(out_dir + out_fn, mode='r', encoding='ascii') as source_fp:
        with open(out_dir + out_fn_2, mode='w', encoding='ascii') as target_fp:
            first_row = True
            for row in source_fp:
                if first_row:
                    row = '%14s%3i' % ('TOTAL NUMBER =', len(IRIS_fn) - failed_files) 
                    row = row + '\n'
                    first_row = False
                target_fp.write(row)

    logging.info('La traducción y escritura de datos de radar RAW terminó')

    return
