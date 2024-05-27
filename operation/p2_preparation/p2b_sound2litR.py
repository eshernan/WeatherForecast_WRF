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


def sound2litR(settings):
    """Convert sounding file

    File specification:
    http://www2.mmm.ucar.edu/wrf/users/wrfda/OnlineTutorial/Help/littler.html
    """

    def process_station(sound_file):
        """Decode a file."""
        f = open(sound_file, "r")
        sounding_lines = f.readlines()

        try:
            #station_id = [line for line in sounding_lines if line.startswith("Station identifier")][0].split(' ')[-1].strip()
            ID = [line.strip() for line in sounding_lines if line.strip().startswith("Station number")][0].split(' ')[-1].strip()
            lat = float([line.strip() for line in sounding_lines if line.strip().startswith("Station latitude")][0].split(' ')[-1].strip())
            lon = float([line.strip() for line in sounding_lines if line.strip().startswith("Station longitude")][0].split(' ')[-1].strip())
            alt = float([line.strip() for line in sounding_lines if line.strip().startswith("Station elevation")][0].split(' ')[-1].strip())
            obs_date = [line.strip() for line in sounding_lines if line.strip().startswith("Observation time")][0].split(' ')[-1].strip()
            #valid_fields = [line.strip() for line in sounding_lines if line.strip().startswith("Levels Number")][0].split(' ')[-1].strip()

            #ID, location, country, lat, lon, alt = get_station_info(station_id)

            # get location
            location = [line.strip() for line in sounding_lines if line.strip().startswith(ID)][0].split(' ')
            location = "/".join([i for i in location if i][1:3])

            # fix observation time
            # i.e. from 160818/1200 to 20161019120000
            obs_date = "20"+obs_date.replace("/", "")+"00"

            # count data rows
            data_rows = 0
            for line in sounding_lines:
                # filter only data
                if not line.strip():
                    continue
                if not len([x for x in line.strip().split(" ") if x]) == 11:
                    continue
                try:
                    [float(i) for i in [x for x in line.strip().split(" ") if x]]
                except:
                    continue
                data_rows += 1
        except:
            logging.error(" ↳ Problemas con el formato, contenido o archivo corrupto")
            logging.warning(" ↳ Continuar sin esta estacion")
            return

        #### station header ####

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
        header_string += str("T").rjust(10)
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

        # set valid_fields
        valid_fields = data_rows * 7
        header_string = header_string.replace("valid_fields", str(valid_fields).rjust(10))

        litR_file.write(header_string + '\n')

        for line in sounding_lines:
            # filter only data
            if not line.strip():
                continue
            if not len([x for x in line.strip().split(" ") if x]) == 11:
                continue
            try:
                [float(i) for i in [x for x in line.strip().split(" ") if x]]
            except:
                continue

            #### station data ####

            data_string = ""

            # Pressure (Pa)
            data_string += str(format(float(line[0:7]) * 100, '.5f')).rjust(13)
            # QC Pressure (Pa)
            data_string += str(0).rjust(7)
            # Height (m)
            data_string += str(format(float(line[7:14]), '.5f')).rjust(13)
            # QC Height (m)
            data_string += str(0).rjust(7)
            # Temperature (K)
            data_string += str(format(float(line[14:21]) + 273.15, '.5f')).rjust(13)
            # QC Temperature (K)
            data_string += str(0).rjust(7)
            # Dew point (K)
            data_string += str(format(float(line[21:28]) + 273.15, '.5f')).rjust(13)
            # QC Dew point (K)
            data_string += str(0).rjust(7)
            # Wind speed (m/s)
            data_string += str(format(float(line[49:56]) * 0.514444, '.5f')).rjust(13)
            # QC Wind speed (m/s)
            data_string += str(0).rjust(7)
            # Wind direction (deg)
            data_string += str(format(float(line[42:49]), '.5f')).rjust(13)
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
            data_string += str(format(float(line[28:35]), '.5f')).rjust(13)
            # QC Relative humidity (%)
            data_string += str(0).rjust(7)
            # Thickness (m)
            data_string += str(format(-888888, '.5f')).rjust(13)
            # QC Thickness (m)
            data_string += str(0).rjust(7)

            litR_file.write(data_string + '\n')

        #### ending fields ####

        litR_file.write("-777777.00000      0" * 2 + str(format(data_rows, '.5f')).rjust(13) +
                        str(0).rjust(7) + "-888888.00000      0" * 7 + '\n')

        litR_file.write(str(valid_fields).rjust(7) + "      0      0" + '\n')

        f.close()

    # output file where save all converted files
    litR_file_path = os.path.join(settings['globals']['run_litr_dir'], "sound", "sound2litR.txt")
    if not os.path.isdir(os.path.dirname(litR_file_path)):
        os.makedirs(os.path.dirname(litR_file_path))
    if os.path.isfile(litR_file_path):
        os.remove(litR_file_path)

    litR_file = open(litR_file_path, "w")

    # process file by file
    for root, dirs, files in os.walk(os.path.join(settings['globals']['data'], "sound")):
        if len(files) != 0:
            files = [x for x in files if not x == "sound2litR.txt"]
            for file in files:
                metar_file = os.path.join(root, file)
                logging.info("Procesando archivo sounding: " + file)
                process_station(metar_file)

    litR_file.close()

