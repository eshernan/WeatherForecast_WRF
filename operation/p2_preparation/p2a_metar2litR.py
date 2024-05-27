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
import string

from scripts_op.libs.utils import dms_parser, dms2dd
from scripts_op.libs.metar import metar  # https://github.com/phobson/python-metar.git


def metar2litR(settings):
    """Convert metar file

    File specification:
    http://www2.mmm.ucar.edu/wrf/users/wrfda/OnlineTutorial/Help/littler.html
    """

    def get_station_info(station_id):

        def search_station(station_id):
            nsd_file = os.path.join(settings['globals']['scripts_dir'], "libs", "nsd_cccc.txt")
            with open(nsd_file) as search:
                for line in search:
                    line = line.strip()
                    if line.split(";")[0] == station_id:
                        return line

        nsd_station = search_station(station_id)

        if nsd_station is None:
            logging.warning(" ↳ No existe la estacion dentro del archivo nsd_cccc.txt")
            return None, None, None, None, None, None

        nsd_parser = nsd_station.split(";")

        try:
            ID = int(nsd_parser[1]+nsd_parser[2])
        except:
            ID = 99
        location = nsd_parser[3]
        country = nsd_parser[5]
        lat = dms2dd(*dms_parser(nsd_parser[7]))
        lon = dms2dd(*dms_parser(nsd_parser[8]))
        alt = float(nsd_parser[11])

        return ID, location, country, lat, lon, alt

    def process_station(line):
        """Decode a single input line."""
        line = line.strip()
        if len(line) and line[0] in string.ascii_uppercase:
            logging.info("Procesando metar: "+line.split(" ")[0])

            #### First fix some input metar string
            # delete KT(E) in wind to KT
            line = line.replace("KT(E)", "KT")

            # decodificando el codigo metar
            try:
                obs = metar.Metar(line)
            except:
                logging.error(" ↳ Problemas decodificando: " + line)
                logging.warning(" ↳ Continuar sin esta estacion")
                return

            #### station header ####

            ID, location, country, lat, lon, alt = get_station_info(obs.station_id)

            if not ID:
                logging.warning(" ↳ Continuar sin esta estacion")
                return

            valid_fields = 0

            header_string = ""

            # lat
            header_string += str(format(lat, '.5f')).rjust(20)
            # lon
            header_string += str(format(lon, '.5f')).rjust(20)
            # ID
            header_string += str(ID).rjust(40)
            # name
            header_string += (location+"/"+country)[:40].rjust(40)
            # platform
            header_string += "FM-15 METAR".ljust(40)
            # source
            header_string += "".rjust(40)
            # elevation
            header_string += str(format(alt, '.5f')).rjust(20)
            # valid fields
            header_string += str(len(obs.code.split(" ")[1::])).rjust(10)
            # errors
            header_string += str(-888888).rjust(10)
            # warnings
            header_string += str(-888888).rjust(10)
            # Sequence number
            header_string += str("0").rjust(10)
            # Num. duplicates
            header_string += str(-888888).rjust(10)
            # Is sounding?
            header_string += str("F").rjust(10)
            # Is bogus?
            header_string += str("F").rjust(10)
            # Discard?
            header_string += str("F").rjust(10)
            # Unix time
            header_string += str(-888888).rjust(10)
            # Julian day
            header_string += str(-888888).rjust(10)
            # Date
            header_string += obs.time.strftime("%Y%m%d%H%M%S").rjust(20)
            # Sea level pressure - SLP (Pa)
            if obs.press_sea_level:
                header_string += str(format(obs.press_sea_level.value() * 100, '.5f')).rjust(13)
            else:
                header_string += str(format(-888888, '.5f')).rjust(13)
            # QC Sea level pressure - SLP (Pa)
            header_string += str(0).rjust(7)
            # Ref Pressure (Pa)
            header_string += str(format(-888888, '.5f')).rjust(13)
            # QC Ref Pressure (Pa)
            header_string += str(0).rjust(7)
            # Ground Temp
            header_string += str(format(-888888, '.5f')).rjust(13)
            # QC Ground Temp
            header_string += str(0).rjust(7)
            # SST
            header_string += str(format(-888888, '.5f')).rjust(13)
            # QC SST
            header_string += str(0).rjust(7)
            # SFC Pressure (Pa)
            header_string += str(format(-888888, '.5f')).rjust(13)
            # QC SFC Pressure (Pa)
            header_string += str(0).rjust(7)
            # Precip
            header_string += str(format(-888888, '.5f')).rjust(13)
            # QC Precip
            header_string += str(0).rjust(7)
            # Daily Max T
            header_string += str(format(-888888, '.5f')).rjust(13)
            # QC Daily Max T
            header_string += str(0).rjust(7)
            # Daily Min T
            header_string += str(format(-888888, '.5f')).rjust(13)
            # QC Daily Min T
            header_string += str(0).rjust(7)
            # Night Min T
            header_string += str(format(-888888, '.5f')).rjust(13)
            # QC Night Min T
            header_string += str(0).rjust(7)
            # 3hr Pres Change
            header_string += str(format(-888888, '.5f')).rjust(13)
            # QC 3hr Pres Change
            header_string += str(0).rjust(7)
            # 24hr Pres Change
            header_string += str(format(-888888, '.5f')).rjust(13)
            # QC 24hr Pres Change
            header_string += str(0).rjust(7)
            # Cloud cover
            header_string += str(format(-888888, '.5f')).rjust(13)
            # QC Cloud cover
            header_string += str(0).rjust(7)
            # Ceiling
            header_string += str(format(-888888, '.5f')).rjust(13)
            # QC Ceiling
            header_string += str(0).rjust(7)
            # Precipitable water
            #header_string += str(format(-888888, '.5f')).rjust(13)
            # QC Precipitable water
            #header_string += str(0).rjust(7)

            litR_file.write(header_string + '\n')

            #### station data ####
            
            data_string = ""

            # Pressure (Pa)
            if obs.press:
                data_string += str(format(float(obs.press.value("MB")) * 100, '.5f')).rjust(13)
                valid_fields += 1
            else:
                data_string += str(format(-888888, '.5f')).rjust(13)
            # QC Pressure (Pa)
            data_string += str(0).rjust(7)
            # Height (m)
            data_string += str(format(alt, '.5f')).rjust(13)
            valid_fields += 1
            # QC Height (m)
            data_string += str(0).rjust(7)
            # Temperature (K)
            if obs.temp:
                data_string += str(format(obs.temp.value("K"), '.5f')).rjust(13)
                valid_fields += 1
            else:
                data_string += str(format(-888888, '.5f')).rjust(13)
            # QC Temperature (K)
            data_string += str(0).rjust(7)
            # Dew point (K)
            if obs.dewpt:
                data_string += str(format(obs.dewpt.value("K"), '.5f')).rjust(13)
                valid_fields += 1
            else:
                data_string += str(format(-888888, '.5f')).rjust(13)
            # QC Dew point (K)
            data_string += str(0).rjust(7)
            # Wind speed (m/s)
            if obs.wind_speed:
                data_string += str(format(obs.wind_speed.value("MPS"), '.5f')).rjust(13)
                valid_fields += 1
            else:
                data_string += str(format(-888888, '.5f')).rjust(13)
            # QC Wind speed (m/s)
            data_string += str(0).rjust(7)
            # Wind direction (deg)
            if obs.wind_dir:
                data_string += str(format(obs.wind_dir.value(), '.5f')).rjust(13)
                valid_fields += 1
            else:
                data_string += str(format(-888888, '.5f')).rjust(13)
            # QC Wind direction (deg)
            data_string += str(0).rjust(7)
            # Wind U (m/s)
            data_string += str(format(-888888, '.5f')).rjust(13)
            # QC Wind U (m/s)
            data_string += str(0).rjust(7)
            # Wind V (m/s)
            data_string += str(format(-888888, '.5f')).rjust(13)
            # QC Wind V (m/s)
            data_string += str(0).rjust(7)
            # Relative humidity (%)
            data_string += str(format(-888888, '.5f')).rjust(13)
            # QC Relative humidity (%)
            data_string += str(0).rjust(7)
            # Thickness (m)
            data_string += str(format(-888888, '.5f')).rjust(13)
            # QC Thickness (m)
            data_string += str(0).rjust(7)

            litR_file.write(data_string + '\n')

            #### ending fields ####

            litR_file.write("-777777.00000      0" * 2 + str(format(1, '.5f')).rjust(13) +
                            str(0).rjust(7) + "-888888.00000      0" * 7 + '\n')

            litR_file.write(str(valid_fields).rjust(7) + "      0      0" + '\n')

    # output file where save all converted files
    litR_file_path = os.path.join(settings['globals']['run_litr_dir'], "metar", "metar2litR.txt")
    if not os.path.isdir(os.path.dirname(litR_file_path)):
        os.makedirs(os.path.dirname(litR_file_path))
    if os.path.isfile(litR_file_path):
        os.remove(litR_file_path)

    litR_file = open(litR_file_path, "w")

    # process file by file
    for root, dirs, files in os.walk(os.path.join(settings['globals']['data'], "metar")):
        if len(files) != 0:
            files = [x for x in files if x.startswith('metar') and not x == "metar2litR.txt"]
            for file in files:
                metar_file = os.path.join(root, file)
                logging.info("Procesando archivo metar: " + file)
                with open(metar_file) as infile:
                    for line in infile:
                        process_station(line)

    litR_file.close()
