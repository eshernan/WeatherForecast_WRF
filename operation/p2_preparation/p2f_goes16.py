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
Listar los archivos OR_ABI-L1b-RadF-M6C*.nc de la carpeta dir_path = /wrf4/data/fecha-dia/goes/

Crear la carpeta /wrf4/run/fecha-dia/wrfda/goes/

Recortar los archivos OR_ABI-L1b-RadF-M6C*.nc y ubicarlos en la carpeta /wrf4/run/fecha-dia/wrfda/goes/
con el nombre OR_ABI-L1b-RadF-M6C*_COL.nc
'''

import logging 
import os

def list_dir_dat(dir_path):
    ''' Listar los archivos OR_ABI-L1b-RadF-M6C*.nc de un directorio.

    Input:  dir_path = carpeta con ubicación de archivos OR_ABI-L1b-RadF-M6C*.nc

    Output: lista de nombres de archivos OR_ABI-L1b-RadF-M6C*.nc en la carpeta dir_path
    '''

    files = []
    # r=root, d=directories, f = files
    for r, d, f in os.walk(dir_path):
        for file in f:
            if ('OR_ABI-L1b-RadF-M6C' in file) and ('_COL' not in file):
                files.append(file)

    return files

def clean_list(in_list):
    '''
    Recorrer la lista in_list y dejar un solo archivo por canal

    retorna new_list
    '''
    
    old_list = sorted(in_list)
    new_list = list()
    chan = 7
    
    while chan <= 16:
        for el in range(len(old_list)):
            if int(old_list[el][19:21]) == chan: #OR_ABI-L1b-RadF-M6C07_G16_s... -> 07
                new_list.append(old_list[el])
                chan = chan + 1
                break

    return new_list

def goes16cut(settings):

    #listar archivos GOES16 de la carpeta /wrf4/data/fecha-dia/goes/
    G16_dir = os.path.join(settings['globals']['data'], "goes/")
    G16_files = list_dir_dat(G16_dir)

    #revisar que haya aunque sea 1 archivo GOES16
    if len(G16_files) == 0:
        print('No existen archivos GOES16 en la carpeta %s' % G16_dir)
        logging.warning('No existen archivos GOES16 en la carpeta %s' % G16_dir)
        return

    #revisar existencia de /wrf4/run/fecha-dia/wrfda/goes/
    G16_out_dir = os.path.join(settings['globals']['run_dir'], "wrfda", "goes/")    

    #creación de carpeta de salida
    if not os.path.isdir(G16_out_dir):
        os.makedirs(G16_out_dir)    

    #limpiar lista de archivos para que tenga un archivo por canal
    G16_files = clean_list(G16_files)

    #Puntos en pixeles que contienen el dominio d01
    #en x: 2110 a 3510, en y: 1770 a 3170 (1400x1400)
    x_i = str(2110)  #NO CAMBIAR
    x_f = str(3510)  #NO CAMBIAR
    y_i = str(1770)  #NO CAMBIAR
    y_f = str(3170)  #NO CAMBIAR

    #recortar los archivos listados en G16_files usando NCO
    for file in G16_files:
        NCO_str = 'ncks -d x,'+x_i+','+x_f+' -d y,'+y_i+','+y_f+' '+G16_dir+file[:-3]+'.nc'+' '+G16_out_dir+file[:-3]+'_COL.nc'
        print(NCO_str)
        logging.info('recortando %s usando NCO' % file)
        logging.info(NCO_str)
        os.system(NCO_str)
     
    return
