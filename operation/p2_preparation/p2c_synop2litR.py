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
import subprocess
import xmltodict

from scripts_op.libs.utils import dms2dd


def synop2litR(settings):
    """Convert synop file

    File specification:
    http://www2.mmm.ucar.edu/wrf/users/wrfda/OnlineTutorial/Help/littler.html
    """
    # TODO: source, sequence number, ceiling, precipitation (acum??)

    def synop_code2dict(synop_code):
        """Convert synop code to dict

        http://metaf2xml.sourceforge.net/
        """
        pipe = subprocess.Popen(["perl", os.path.join(settings['globals']['scripts_dir'], "libs", "synop2xml", "metaf2xml.pl"),
                                 "-o-", synop_code], stdout=subprocess.PIPE)

        xml_code = pipe.stdout.read().decode("utf-8")

        pipe.stdout.close()

        synop_dict = xmltodict.parse(xml_code)

        return synop_dict['data']['reports']['synop']

    def process_station(station_info, station_synop):

        synop_dict = synop_code2dict(" ".join(station_synop.split(" ")[1:]))

        #### get/set info stations
        ID = station_synop.split(" ")[3]
        location = ",".join(station_info[0].split(",")[1:]).strip()
        lat = dms2dd(station_info[1].strip().split("-")[0], station_info[1].strip().split("-")[1][:-1],
                     0, station_info[1].strip().split("-")[1][-1])
        lon = dms2dd(station_info[2].strip().split("-")[0], station_info[2].strip().split("-")[1][:-1],
                     0, station_info[2].strip().split("-")[1][-1])
        alt = float(station_info[3].strip().split(" ")[0])

        obs_date = station_synop.split(" ")[0] + "00"

        #### station header ####

        valid_fields = 0
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
        header_string += "FM-12 SYNOP".ljust(40)
        # source
        header_string += "".rjust(40)
        # elevation
        header_string += str(format(alt, '.5f')).rjust(20)
        # valid fields
        header_string += "valid_fields"
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
        try:
            header_string += str(format(float(synop_dict["SLP"]["pressure"]["@v"]) * 100, '.5f')).rjust(13)
            valid_fields += 1
        except:
            header_string += str(format(-888888, '.5f')).rjust(13)
        # QC Sea level pressure - SLP (Pa)
        header_string += str(0).rjust(7)
        # Ref Pressure (Pa)
        header_string += str(format(-888888, '.5f')).rjust(13)
        # QC Ref Pressure (Pa)
        header_string += str(0).rjust(7)
        # Ground Temp
        try:
            header_string += str(format(float(synop_dict["temperature"]["air"]["temp"]["@v"]) + 273.15, '.5f')).rjust(13)
            valid_fields += 1
        except:
            header_string += str(format(-888888, '.5f')).rjust(13)
        # QC Ground Temp
        header_string += str(0).rjust(7)
        # SST
        header_string += str(format(-888888, '.5f')).rjust(13)
        # QC SST
        header_string += str(0).rjust(7)
        # SFC Pressure (Pa)
        try:
            header_string += str(format(float(synop_dict["stationPressure"]["pressure"]["@v"]) * 100, '.5f')).rjust(13)
            valid_fields += 1
        except:
            header_string += str(format(-888888, '.5f')).rjust(13)
        # QC SFC Pressure (Pa)
        header_string += str(0).rjust(7)
        # Precip
        try:
            header_string += str(format(float(synop_dict["precipitation"]["precipAmount"]["@v"]), '.5f')).rjust(13)
            valid_fields += 1
        except:
            header_string += str(format(-888888, '.5f')).rjust(13)
        # QC Precip
        header_string += str(0).rjust(7)
        # Daily Max T
        header_string += str(format(-888888, '.5f')).rjust(13)
        # QC Daily Max T
        header_string += str(0).rjust(7)
        # Daily Min T
        try:
            header_string += str(format(float(synop_dict["synop_section3"]["tempMinGround"]["temp"]["@v"]) + 273.15, '.5f')).rjust(13)
            valid_fields += 1
        except:
            header_string += str(format(-888888, '.5f')).rjust(13)
        # QC Daily Min T
        header_string += str(0).rjust(7)
        # Night Min T
        try:
            header_string += str(format(float(synop_dict["synop_section3"]["tempMinNighttime"]["temp"]["@v"]) + 273.15, '.5f')).rjust(13)
            valid_fields += 1
        except:
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

        #### station data ####

        data_string = ""

        # Pressure (Pa)
        try:
            data_string += str(format(float(synop_dict["stationPressure"]["pressure"]["@v"]) * 100, '.5f')).rjust(13)
            valid_fields += 1
        except:
            data_string += str(format(-888888, '.5f')).rjust(13)
        # QC Pressure (Pa)
        data_string += str(0).rjust(7)
        # Height (m)
        data_string += str(format(alt, '.5f')).rjust(13)
        # QC Height (m)
        data_string += str(0).rjust(7)
        # Temperature (K)
        try:
            data_string += str(format(float(synop_dict["temperature"]["air"]["temp"]["@v"]) + 273.15, '.5f')).rjust(13)
            valid_fields += 1
        except:
            data_string += str(format(-888888, '.5f')).rjust(13)
        # QC Temperature (K)
        data_string += str(0).rjust(7)
        # Dew point (K)
        try:
            data_string += str(format(float(synop_dict["temperature"]["dewpoint"]["temp"]["@v"]) + 273.15, '.5f')).rjust(13)
            valid_fields += 1
        except:
            data_string += str(format(-888888, '.5f')).rjust(13)
        # QC Dew point (K)
        data_string += str(0).rjust(7)
        # Wind speed (m/s)
        try:
            data_string += str(format(float(synop_dict["sfcWind"]["wind"]["speed"]["@v"]), '.5f')).rjust(13)
            valid_fields += 1
        except:
            data_string += str(format(-888888, '.5f')).rjust(13)
        # QC Wind speed (m/s)
        data_string += str(0).rjust(7)
        # Wind direction (deg)
        try:
            data_string += str(format(float(synop_dict["sfcWind"]["wind"]["dir"]["@v"]), '.5f')).rjust(13)
            valid_fields += 1
        except:
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
        try:
            data_string += str(format(float(synop_dict["temperature"]["relHumid1"]["@v"]), '.5f')).rjust(13)
            valid_fields += 1
        except:
            data_string += str(format(-888888, '.5f')).rjust(13)
        # QC Relative humidity (%)
        data_string += str(0).rjust(7)
        # Thickness (m)
        data_string += str(format(-888888, '.5f')).rjust(13)
        # QC Thickness (m)
        data_string += str(0).rjust(7)

        # set valid_fields
        header_string = header_string.replace("valid_fields", str(valid_fields).rjust(10))

        # write to file
        litR_file.write(header_string + '\n')
        litR_file.write(data_string + '\n')

        #### ending fields ####

        litR_file.write("-777777.00000      0"*2 + str(format(1, '.5f')).rjust(13) +
                        str(0).rjust(7) + "-888888.00000      0"*7 + '\n')

        litR_file.write(str(valid_fields).rjust(7) + "      0      0" + '\n')

    # output file where save all converted files
    litR_file_path = os.path.join(settings['globals']['run_litr_dir'], "synop", "synop2litR.txt")
    if not os.path.isdir(os.path.dirname(litR_file_path)):
        os.makedirs(os.path.dirname(litR_file_path))
    if os.path.isfile(litR_file_path):
        os.remove(litR_file_path)

    litR_file = open(litR_file_path, "w")

    # input synop file
    synop_file = os.path.join(settings['globals']['data'], "synop", "synops.txt")
    station_info = ""
    station_synop = ""
    with open(synop_file) as infile:
        for line in infile:
            line = line.strip()
            if not line or len(line) == 0:
                continue
            if line.startswith("##########"):
                continue

            if line.startswith("#  SYNOPS"):
                station_info = line.split("|")
                continue

            station_synop += " " + line

            if line.endswith("=="):
                logging.info("Procesando estacion synop: " + ",".join(station_info[0].split(",")[1:]).strip())
                process_station(station_info, station_synop.strip())
                station_synop = ""

    litR_file.close()
