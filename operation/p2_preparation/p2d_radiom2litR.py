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
import csv
import logging
import os

from scripts_op.libs.utils import dms_parser, dms2dd


def radiom2litR(settings):
    """Convert radiometers file

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
            logging.error(" ↳ No existe la estacion dentro del archivo nsd_cccc.txt")
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

    def process_station(radiom_file):
        """Decode a file."""
        f = open(radiom_file, "r")
        radiom_csv = list(csv.reader(f, delimiter=','))

        for line_num, line in enumerate(radiom_csv):
            # clear line list of empty strings
            line = [i for i in line if i]

            # save line 201 for Zenith observation
            if line[2].strip() == "201":
                if line_num+1 < len(radiom_csv) and radiom_csv[line_num+1][2].strip() == "401" and \
                            radiom_csv[line_num+1][3].strip() in ["Zenith", "ZenithKV", "Zenith-V"]:
                    line_201 = line

            #### station header ####

            if line[2].strip() == "401" and line[3].strip() in ["Zenith", "ZenithKV", "Zenith-V"]:
                obs_date = line[1]
                obs_date = obs_date.split(" ")
                obs_date = "20"+obs_date[0].split("/")[2]+obs_date[0].split("/")[0]+obs_date[0].split("/")[1]+"".join(obs_date[1].replace(":", ""))
                ground_temp = line_201[3]
                sfc_pressure = line_201[5]
                rain = line_201[7]

                try:
                    station_id = os.path.basename(radiom_file)[0:4].upper()
                    ID, location, country, lat, lon, alt = get_station_info(station_id)
                    if not ID:
                        logging.warning(" ↳ Continuar sin esta estacion")
                        return
                except:
                    logging.error(" ↳ Problemas con el formato, contenido o archivo corrupto")
                    logging.warning(" ↳ Continuar sin esta estacion")
                    return

                header_string = ""

                # lat
                header_string += str(format(lat, '.5f')).rjust(20)
                # lon
                header_string += str(format(lon, '.5f')).rjust(20)
                # ID
                header_string += str(ID).rjust(40)
                # name
                header_string += location[:40].rjust(40)
                # platform
                header_string += "FM-35 TEMP".ljust(40)
                # source
                header_string += "".rjust(40)
                # elevation
                header_string += str(format(alt, '.5f')).rjust(20)
                # valid fields
                header_string += str(len(heights)*3).rjust(10)
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
                header_string += obs_date.rjust(20)
                # Sea level pressure - SLP (Pa)
                header_string += str(format(-888888, '.5f')).rjust(13)
                # QC Sea level pressure - SLP (Pa)
                header_string += str(0).rjust(7)
                # Ref Pressure (Pa)
                header_string += str(format(-888888, '.5f')).rjust(13)
                # QC Ref Pressure (Pa)
                header_string += str(0).rjust(7)
                # Ground Temp
                header_string += str(format(float(ground_temp), '.5f')).rjust(13)
                # QC Ground Temp
                header_string += str(0).rjust(7)
                # SST
                header_string += str(format(-888888, '.5f')).rjust(13)
                # QC SST
                header_string += str(0).rjust(7)
                # SFC Pressure (Pa)
                header_string += str(format(float(sfc_pressure), '.5f')).rjust(13)
                # QC SFC Pressure (Pa)
                header_string += str(0).rjust(7)
                # Precip
                header_string += str(format(float(rain), '.5f')).rjust(13)
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
                # header_string += str(format(-888888, '.5f')).rjust(13)
                # QC Precipitable water
                # header_string += str(0).rjust(7)

                litR_file.write(header_string + '\n')

            #### station data ####

            if line[2].strip() == "400" and line[3].strip() == "LV2 Processor":
                station_id = os.path.basename(radiom_file)[0:4].upper()
                ID, location, country, lat, lon, alt = get_station_info(station_id)
                heights = [(float(x)*1000)+alt for x in line[4:-2]]

            if line[2].strip() == "401" and line[3].strip() in ["Zenith", "ZenithKV", "Zenith-V"]:
                temperatures = line[4:-2]

            if line[2].strip() == "404" and line[3].strip() in ["Zenith", "ZenithKV", "Zenith-V"]:
                relatives_humidity = line[4:-2]

                for height, temperature, relative_humidity in zip(heights, temperatures, relatives_humidity):

                    data_string = ""

                    # Pressure (Pa)
                    data_string += str(format(-888888, '.5f')).rjust(13)
                    # QC Pressure (Pa)
                    data_string += str(0).rjust(7)
                    # Height (m)
                    data_string += str(format(float(height), '.5f')).rjust(13)
                    # QC Height (m)
                    data_string += str(0).rjust(7)
                    # Temperature (K)
                    data_string += str(format(float(temperature), '.5f')).rjust(13)
                    # QC Temperature (K)
                    data_string += str(0).rjust(7)
                    # Dew point (K)
                    data_string += str(format(-888888, '.5f')).rjust(13)
                    # QC Dew point (K)
                    data_string += str(0).rjust(7)
                    # Wind speed (m/s)
                    data_string += str(format(-888888, '.5f')).rjust(13)
                    # QC Wind speed (m/s)
                    data_string += str(0).rjust(7)
                    # Wind direction (deg)
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
                    data_string += str(format(float(relative_humidity), '.5f')).rjust(13)
                    # QC Relative humidity (%)
                    data_string += str(0).rjust(7)
                    # Thickness (m)
                    data_string += str(format(-888888, '.5f')).rjust(13)
                    # QC Thickness (m)
                    data_string += str(0).rjust(7)

                    litR_file.write(data_string + '\n')

                #### ending fields ####

                litR_file.write("-777777.00000      0" * 2 + str(format(len(heights), '.5f')).rjust(13) +
                                str(0).rjust(7) + "-888888.00000      0" * 7 + '\n')

                litR_file.write(str(len(heights)*3).rjust(7) + "      0      0" + '\n')

        f.close()

    # output file where save all converted files
    litR_file_path = os.path.join(settings['globals']['run_litr_dir'], "radiom", "radiom2litR.txt")
    if not os.path.isdir(os.path.dirname(litR_file_path)):
        os.makedirs(os.path.dirname(litR_file_path))
    if os.path.isfile(litR_file_path):
        os.remove(litR_file_path)

    litR_file = open(litR_file_path, "w")

    # process file by file
    for root, dirs, files in os.walk(os.path.join(settings['globals']['data'], "radiom")):
        if len(files) != 0:
            files = [x for x in files if x.endswith('.csv')]
            for file in files:
                metar_file = os.path.join(root, file)
                logging.info("Procesando radiometro: " + file)
                process_station(metar_file)

    litR_file.close()
