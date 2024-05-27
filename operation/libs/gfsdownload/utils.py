#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on 16 déc. 2013

@author: yoann Moreau
@author: Xavier Corredor Llano

All controls operations :
return true if control ok
"""

import errno
import os
import re
from datetime import date, datetime, timedelta
from urllib.request import urlopen


def checkForFile(pathToFile):
    if os.path.isfile(pathToFile):
        return True
    else:
        return False


def createParamFile(pathFile, user, key):
    f = open(pathFile, 'w+')
    f.write("{\n")
    f.write(' "url"   : "https://api.ecmwf.int/v1",\n')
    f.write('"key"   : "' + key + '",\n')
    f.write('"email" : "' + user + '"\n')
    f.write("}")
    f.close()


def make_sure_path_exists(path):
    try:
        os.makedirs(path)
    except OSError as exception:
        if exception.errno != errno.EEXIST:
            raise


def checkForFolder(pathToFolder):
    try:
        os.makedirs(pathToFolder)
    except OSError as exception:
        if exception.errno != errno.EEXIST:
            exit('Path for downloaded Era Interim could not be create. Check your right on the parent folder...')


def checkForDate(dateC):
    # convert string to date from YYYY-MM-DD

    if len(dateC) == 10:
        YYYY = dateC[0:4]
        MM = dateC[5:7]
        DD = dateC[8:10]
        if (YYYY.isdigit() and MM.isdigit() and DD.isdigit()):
            try:
                date(int(YYYY), int(MM), int(DD))
            except ValueError:
                exit('Error on Date Format... please give a date in YYYY-MM-DD format')

            return date(int(YYYY), int(MM), int(DD))

        else:
            exit('Error on Date Format... please give a date in YYYY-MM-DD format')
    else:
        exit('Error on Date Format... please give a date in YYYY-MM-DD format')


def is_float_re(element):
    _float_regexp = re.compile(r"^[-+]?(?:\b[0-9]+(?:\.[0-9]*)?|\.[0-9]+\b)(?:[eE][-+]?[0-9]+\b)?$").match
    return True if _float_regexp(element) else False


def checkForExtendValidity(extendList):
    if len(extendList) == 4 and all([is_float_re(str(x)) for x in extendList]) and extendList[0] > extendList[2] and \
                    extendList[1] < extendList[3]:
        if float(extendList[0]) > -180 and float(extendList[2]) < 180 and float(extendList[1]) < 90 and float(
                extendList[3]) > -90:
            extendArea = [str(x) for x in extendList]
            return extendArea
        else:
            exit('Projection given is not in WGS84. Please verify your -t parameter')
    else:
        exit('Area scpecified is not conform to a  ymax xmin ymin xmax  extend. please verify your declaration')


def checkForLevelValidity(levelList):
    levelPossible = ['all', '0-0.1_m_below_ground', '0.1-0.4_m_below_ground', '0.33-1_sigma_layer',
                     '0.4-1_m_below_ground', '0.44-0.72_sigma_layer', '0.44-1_sigma_layer', '0.72-0.94_sigma_layer',
                     '0.995_sigma', '0C_isotherm', '1000_mb', '100_m_above_ground', '100_mb', '10_m_above_ground',
                     '10_mb', '1-2_m_below_ground', '150_mb', '180-0_mb_above_ground', '1829_m_above_mean_sea',
                     '200_mb', '20_mb', '250_mb', '255-0_mb_above_ground', '2743_m_above_mean_sea', '2_m_above_ground',
                     '3000-0_m_above_ground', '300_mb', '30-0_mb_above_ground', '30_mb', '350_mb',
                     '3658_m_above_mean_sea', '400_mb', '450_mb', '500_mb', '50_mb', '550_mb', '6000-0_m_above_ground',
                     '600_mb', '650_mb', '700_mb', '70_mb', '750_mb', '800_mb', '80_m_above_ground', '850_mb', '900_mb',
                     '925_mb', '950_mb', '975_mb', 'boundary_layer_cloud_layer', 'convective_cloud_bottom',
                     'convective_cloud_layer', 'convective_cloud_top', 'entire_atmosphere',
                     'entire_atmosphere_%5C%28considered_as_a_single_layer%5C%29', 'high_cloud_bottom',
                     'high_cloud_layer', 'high_cloud_top', 'tropopause', 'highest_tropospheric_freezing',
                     'low_cloud_bottom', 'low_cloud_layer', 'low_cloud_top', 'max_wind', 'mean_sea',
                     'middle_cloud_bottom', 'middle_cloud_layer', 'middle_cloud_top', 'planetary_boundary_layer',
                     'PV%3D-2e-06_%5C%28Km%5C%5E2%2Fkg%2Fs%5C%29_surface',
                     'PV%3D2e-06_%5C%28Km%5C%5E2%2Fkg%2Fs%5C%29_surface', 'surface', 'top_of_atmosphere']
    if all([x in levelPossible for x in levelList]):
        return levelList
    else:
        exit('One or more level declared is not available. Please choose one in those  : %s' % '\n'.join(levelPossible))


def checkForParams(codeGFS):
    codeGFSPossible = ['all', '4LFTX', '5WAVH', 'ABSV', 'ACPCP', 'ALBDO', 'APCP', 'CAPE', 'CFRZR', 'CICEP', 'CIN',
                       'CLWMR', 'CPOFP', 'CPRAT', 'CRAIN', 'CSNOW', 'CWAT', 'CWORK', 'DLWRF', 'DPT', 'DSWRF', 'FLDCP',
                       'GFLUX', 'GUST', 'HGT', 'HINDEX', 'HLCY', 'HPBL', 'ICAHT', 'ICEC', 'LAND', 'LFTX', 'LHTFL',
                       'MSLET', 'O3MR', 'PEVPR', 'PLPL', 'POT', 'PRATE', 'PRES', 'PRMSL', 'PWAT', 'RH', 'SHTFL', 'SNOD',
                       'SOILW', 'SPFH', 'SUNSD', 'TCDC', 'TMAX', 'TMIN', 'TMP', 'TOZNE', 'TSOIL', 'UFLX', 'UGRD',
                       'U-GWD', 'ULWRF', 'USTM', 'USWRF', 'VFLX', 'VGRD', 'V-GWD', 'VRATE', 'VSTM', 'VVEL', 'VWSH',
                       'WATR', 'WEASD', 'WILT']

    if all([x in codeGFSPossible for x in codeGFS]):
        return codeGFS
    else:
        exit('One or more level declared is not available. Please choose one in those  : %s' % '\n'.join(
            codeGFSPossible))


def checkForProductValidity(listTime):
    validParameters = ('00', '06', '12', '18')

    if len(listTime) > 0 and isinstance(listTime, list) and all([x in validParameters for x in listTime]):
        return listTime
    else:
        exit('time parameters not conform to GFS posibility : ' + ",".join(validParameters))


def checkForStepValidity(listStep):
    validParameters = (0, 6, 12, 18)

    if len(listStep) > 0 and isinstance(listStep, list) and all([int(x) in validParameters for x in listStep]):
        listStep = [int(x) for x in listStep]
        return listStep
    else:
        exit('step parameters not conform to GFS posibility : ' + ",".join([str(x) for x in validParameters]))


def checkForGridValidity(grid):
    validParameters = (0.25, 0.5, 1, 2.5)
    if is_float_re(grid):
        grid = float(grid)

        if grid in validParameters:
            return grid
        else:
            exit(
                'grid parameters not conform to posibility : ' + ",".join([str(x) for x in validParameters]))
    else:
        exit('grid parameters not conform to posibility : ' + ",".join([str(x) for x in validParameters]))


def fix_zeros(value, digits):
    if digits == 2:
        return '0'+str(value) if len(str(value))<2 else str(value)
    if digits == 3:
        return '00'+str(value) if len(str(value))==1 else ('0'+str(value) if len(str(value))==2 else str(value))


def create_request_gfs(dateStart, dateEnd, stepList, levelList, grid, extent, paramList, typeData, forecast_hours):
    """
        Genere la structure de requete pour le téléchargement de données GFS
        
        INPUTS:\n
        -date : au format annee-mois-jour\n
        -heure : au format heure:minute:seconde\n
        -coord : une liste des coordonnees au format [N,W,S,E]\n
        -dim_grille : taille de la grille en degree \n
    """

    URLlist = []

    # Control datetype
    listforecastSurface = ['GUST', 'HINDEX', 'PRES', 'HGT', 'TMP', 'WEASD', 'SNOD', 'CPOFP', 'WILT', 'FLDCP', 'SUNSD',
                           'LFTX', 'CAPE', 'CIN', '4LFTX', 'HPBL', 'LAND']
    if (0 not in [int(x) for x in stepList]):
        listforecastSurface = listforecastSurface + ['PEVPR', 'CPRAT', 'PRATE', 'APCP', 'ACPCP', 'WATR', 'CSNOW',
                                                     'CICEP', 'CFPER', 'CRAIN', 'LHTFL', 'SHTFL', 'SHTFL', 'GFLUX',
                                                     'UFLX', 'VFLX', 'U-GWD', 'V-GWD', 'DSWRF', 'DLWRF', 'ULWRF',
                                                     'USWRF', 'ALBDO']
    listAnalyseSurface = ['HGT', 'PRES', 'LFTX', 'CAPE', 'CIN', '4LFTX']

    if typeData == 'analyse' and all([x in listAnalyseSurface for x in paramList]):
        typeData = 'analyse'
        validChoice = None
        prbParameters = None
    else:
        if all([x in listforecastSurface for x in paramList]) and typeData != 'cycleforecast':
            if typeData == 'analyse':
                typeData = 'forecast'
                validChoice = typeData
            else:
                validChoice = None
            indexParameters = [i for i, elem in enumerate([x in listAnalyseSurface for x in paramList], 1) if not elem]
            prbParameters = []
            for i in indexParameters:
                prbParameters.append(paramList[i - 1])
        else:
            if typeData != 'cycleforecast':
                typeData = 'cycleforecast'
                validChoice = typeData
            else:
                validChoice = None
            indexParameters = [i for i, elem in enumerate([x in listAnalyseSurface for x in paramList], 1) if not elem]
            prbParameters = []
            for i in indexParameters:
                prbParameters.append(paramList[i - 1])

    # Control si date/timeList disponible
    UTC_today = datetime.utcnow()
    lastData = UTC_today - timedelta(days=14)
    if dateStart < lastData.date() or dateEnd > UTC_today.date():
        exit('date are not in 14 days range from UTC today')
    else:
        # Pour chaque jour souhaité
        nbDays = (dateEnd - dateStart).days + 1
        for i in range(0, nbDays):
            # on crontrole pour les timeList
            if dateStart + timedelta(days=i) == UTC_today:
                maxT = datetime.utcnow().hour + 4
                timeList = [x for x in stepList if x < maxT]
            else:
                timeList = stepList
            for t in timeList:
                if forecast_hours == 'anl':
                    hoursList = ['anl']
                else:
                    start = int(forecast_hours.split('-')[0])
                    stop = int(forecast_hours.split('-')[1])
                    step = int(forecast_hours.split('-')[2])
                    hoursList = range(start, stop+1, step)

                for h in hoursList:
                    URL = 'https://nomads.ncep.noaa.gov/cgi-bin/filter_gfs_'
                    # grid
                    URL += "{:.2f}".format(grid).replace('.', 'p') + '.pl?file=gfs.'
                    # time ( attention limiter avec décalage horaire for UTC_today
                    URL += 't' + str(t).zfill(2) + 'z.'
                    if grid == 0.5:
                        URL += 'pgrb2full.'
                    else:
                        URL += 'pgrb2.'
                    URL += "{:.2f}".format(grid).replace('.', 'p') + '.'

                    if h == 'anl':
                        URL += h + '&'
                    else:
                        URL += 'f' + fix_zeros(h, 3) + '&'

                    if levelList == ['all'] and paramList == ['all']:
                        URL += "all_lev" + "=on&all_var" + "=on&subregion=&"
                    elif levelList == ['all'] and not paramList == ['all']:
                        URL += "all_lev=on&var_" + "=on&var_".join(paramList) + "=on&subregion=&"
                    elif not levelList == ['all'] and paramList == ['all']:
                        URL += "lev_" + "=on&lev_".join(levelList) + "=on&all_var" + "=on&subregion=&"
                    else:
                        URL += "lev_" + "=on&lev_".join(levelList) + "=on&var_"
                        URL += "=on&var_".join(paramList) + "=on&subregion=&"
                    URL += "leftlon=" + str(round(float(extent[1]) - 0.05, 1)) + "&rightlon=" + str(
                        round(float(extent[3]) + 0.05, 1)) + "&toplat=" + str(
                        round(float(extent[0]) + 0.5, 1)) + "&bottomlat=" + str(round(float(extent[2]) - 0.5, 1))
                    URL += "&dir=%2Fgfs." + "{:%Y%m%d}".format(dateStart + timedelta(days=i)) + "%2F" +str(t).zfill(2)+"%2Fatmos"
                    URLlist.append(URL)

        return (URLlist, validChoice, prbParameters)


def GFSDownload(pathToFile, pathToOutputFile):

    try:
        response = urlopen(pathToFile)
        html = response.read()
    except Exception as err:
        print("URL problem response while downloading file")
        print(err)
        return False

    if len(html) > 0:
        f = open(pathToOutputFile, 'wb')
        f.write(html)
        f.close()
        return True
    else:
        print("Error while downloading file")
        return False
