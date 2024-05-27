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
import shutil
import signal
import socket
from configparser import ConfigParser
from datetime import datetime
from glob import glob


class SettingsParser(ConfigParser):
    def as_dict(self):
        d = dict(self._sections)
        for k in d:
            d[k] = dict(self._defaults, **d[k])
            d[k].pop('__name__', None)
        return d


def kill_process_by_name(pstring):
    for line in os.popen("ps ax | grep " + pstring + " | grep -v grep"):
        fields = line.split()
        pid = fields[0]
        try:
            os.kill(int(pid), signal.SIGKILL)
        except: pass


class FileLock(object):
    """Class to handle creating and removing (pid) lockfiles"""
    list_process = ["wrf.exe", "real.exe", "da_update_bc.exe", "obsproc.exe", "da_wrfvar.exe", "metgrid.exe", "ungrib.exe", ]

    def __init__(self, flock_path):
        self.pid = os.getpid()
        self.flock_path = flock_path

    def acquire(self):
        """Acquire a lock, returning self if successful, False otherwise"""
        if self.islocked():
            logging.warning("Se detecto un proceso anterior corriendo, PID: "+self.old_pid)
            logging.warning("Se matara para continuar y ejecutar el actual")
            self.kill_old_process()
            self.release()

        fl = open(self.flock_path, 'w')
        fl.write(str(self.pid))
        fl.close()

    def islocked(self):
        """Check if we already have a lock"""
        try:
            fh = open(self.flock_path)
            self.old_pid = fh.read().rstrip()
            fh.close()
            return True
        except:
            return False

    def kill_old_process(self):
        try:
            os.kill(int(self.old_pid), signal.SIGKILL)
        except: pass

        try:
            [kill_process_by_name(process) for process in FileLock.list_process]
        except: pass

    def release(self):
        try:
            os.remove(self.flock_path)
        except: pass


def dms2dd(degrees, minutes, seconds, direction):
    dd = float(degrees) + float(minutes)/60 + float(seconds)/(60*60)
    if direction.upper() == 'S' or direction.upper() == 'W':
        dd *= -1
    return dd


def dd2dms(deg):
    d = int(deg)
    md = abs(deg - d) * 60
    m = int(md)
    sd = (md - m) * 60
    return [d, m, sd]


def dms_parser(dms_string):
    """
    Convert dms string like: 081-45-24W to decimal
    """
    dms_string = dms_string.split("-")

    if len(dms_string) == 3:
        degrees = dms_string[0]
        minutes = dms_string[1]
        seconds = dms_string[2][0:-2]
        direction = dms_string[2][-1]

        return degrees, minutes, seconds, direction

    if len(dms_string) == 2:
        degrees = dms_string[0]
        minutes = dms_string[1][0:-2]
        seconds = 0
        direction = dms_string[1][-1]

        return degrees, minutes, seconds, direction


def log_format(string, level):
    """
    Title format
    """
    if level == 1:
        count_string = len(string) + 2
        return ("#" * int((70 - count_string) / 2) + " " + string + " " +
                "#" * int((70 - count_string) / 2)).rjust(70, "#")

    if level == 2:
        count_string = len(string) + 2
        return ("-" * int((70 - count_string) / 2) + " " + string + " " +
                "-" * int((70 - count_string) / 2)).rjust(70, "-")


def delete_files(files_path, patterns):
    """
    Delete files with pattern like (*.txt, meta*) and single file (file.txt)
    """
    if isinstance(patterns, str):
        patterns = [patterns]
    starts_pattern = [pattern.replace("*", "") for pattern in patterns if pattern.endswith("*")]
    ends_pattern = [pattern.replace("*", "") for pattern in patterns if pattern.startswith("*")]

    for file_in_path in os.listdir(files_path):
        if any([file_in_path.startswith(pattern) for pattern in starts_pattern]) or \
                any([file_in_path.endswith(pattern) for pattern in ends_pattern]):
            os.remove(os.path.join(files_path, file_in_path))
        elif file_in_path in patterns:
            os.remove(os.path.join(files_path, file_in_path))


def search_error(log_file, str_error):
    """
    Search error string in log file
    """
    with open(log_file, "r") as log:
        return any([str_error in line for line in log])


def check_files(files_path, patterns):
    """
    Check files patterns exists in files path
    """
    if isinstance(patterns, str):
        patterns = [patterns]
    starts_pattern = [pattern.replace("*", "") for pattern in patterns if pattern.endswith("*")]
    ends_pattern = [pattern.replace("*", "") for pattern in patterns if pattern.startswith("*")]

    for file_in_path in os.listdir(files_path):
        if any([file_in_path.startswith(pattern) for pattern in starts_pattern]) or \
                any([file_in_path.endswith(pattern) for pattern in ends_pattern]):
            return True
        elif file_in_path in patterns:
            return True
    return False


def check_node_up(node_host):
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        s.connect((node_host, 22))
        status = True
    except:
        status = False
        logging.warning("Nodo {} no accesible".format(node_host))
    s.close()
    return status


def mpiexec(settings, run_in="all"):
    """
    Return mpiexec command for run in parallel

    :return: mpiexec command
    :rtype: list
    """
    # settings nodes to run
    if run_in == "all":
        run_in = settings['process']['mpi_nodes'].split(",")
    elif isinstance(run_in, str):
        run_in = [run_in]

    # verificacion de accesibilidad en los nodos
    nodes_up = []
    for node in run_in:
        if check_node_up(node) or node == "master":
            nodes_up.append(node)
    # machinefile
    machinefile = os.path.join(settings['globals']['run_dir'], "logs", "mpd.conf")
    with open(machinefile, "w+") as mfile:
        [mfile.write(node_up+"\n") for node_up in nodes_up]

    total_process = len(nodes_up) * int(settings['process']['mpi_ppn'])

    return ["mpiexec.hydra", "-machinefile", machinefile, "-np", str(total_process),
            "-ppn", settings['process']['mpi_ppn']]


def send_mail(sender, receiver, subject, body, files_attached=None):
    import smtplib
    import base64
    from email.mime.text import MIMEText
    from email.mime.application import MIMEApplication
    from email.mime.multipart import MIMEMultipart

    # Create a text/plain message
    msg = MIMEMultipart()
    msg["Subject"] = subject
    msg["From"] = sender
    msg["To"] = receiver

    # This is the textual part:
    part = MIMEText(body, _charset="utf-8")
    msg.attach(part)

    # This is the binary part(The Attachment) if is not None:
    if files_attached is not None and len(files_attached) != 0:
        for file_attached in files_attached:
            part = MIMEApplication(open(file_attached, "rb").read())
            part.add_header("Content-Disposition", "attachment", filename=os.path.basename(file_attached))
            msg.attach(part)

    # servidor SMTP
    server = smtplib.SMTP("172.20.100.210", 25)

    # autenticacion en el servidor SMTP, para ello:
    # definir las siguientes variables dentro del .bashrc del usuario que
    # ejecuta el proceso de automatizacion (~/.bashrc):
    #   export login_smtp_user=<user@mail>
    #   export login_smtp_password=<password>
    server.login(os.environ.get('login_smtp_user'), os.environ.get('login_smtp_password'))
    server.sendmail(msg["From"], msg["To"].split(","), msg.as_string())
    server.quit()


def email_report(settings, files_attached=None):
    if files_attached is None:
        files_attached = []

    mail_subject = "Reporte de la corrida del modelo WRF para {0} {1}"\
        .format(settings['globals']['start_date'].strftime("%Y-%m-%d_%H"),
                settings['globals']['run_type'],)

    mail_body = \
        '\n{0}\n\nEste es el reporte automático de la corrida del modelo WRF\n' \
        'Fecha de corrida: {0}\n' \
        'Tipo de corrida: {1}\n' \
        'Fecha del reporte: {2}\n\n' \
            .format(settings['globals']['start_date'].strftime("%Y-%m-%d_%H"),
                    settings['globals']['run_type'], datetime.today().strftime("%Y-%m-%d %H:%M:%S"))

    if settings['globals']['run_type'] == "cold":
        logs_dir = "/wrf4/run/{}/logs".format(settings['globals']['start_date'].strftime("%Y%m%d-%H"))
    if settings['globals']['run_type'] == "warm":
        logs_dir = "/wrf4/rap/{}/logs".format(settings['globals']['start_date'].strftime("%Y%m%d-%H"))

    mail_body += '\nOcurrio un problema en la corrida, revisar el main.log y/o ' \
                 'revisar el proceso ubicado en {}\n'.format(logs_dir)

    if len(files_attached) > 0:
        mail_body += '\nAdjunto se envía el log principal del reporte del proceso.\n'

    receivers = "julian.pantoja@fac.mil.co,edwin.bocanegra@fac.mil.co,juan.sotob@fac.mil.co"

    send_mail(os.environ.get('login_smtp_user'), receivers, mail_subject, mail_body, files_attached)


def free_spaces_before_run(settings):

    # paths
#    original_destination = "/wrf4"
#    backup_destination = "/disco1"
    original_destination = settings['globals']['original_destination']
    backup_destination = settings['globals']['backup_destination']

    ### delete in backup destination
    # XX Gb minimo de espacio libre
    min_free_space = 80
    t, u, f = shutil.disk_usage(backup_destination)
    free_space = f/1073741824
    while free_space < min_free_space:
        old_runs = []
        for type_run in ["run", "rap"]:
            date_paths = {}
            for dir in glob(backup_destination + "/" + type_run + "/*/"):
                try:
                    dir_date = datetime.strptime(dir.split("/")[-2], "%Y%m%d-%H")
                except:
                    continue
                date_paths[dir_date] = dir
            if date_paths:
                sorted_dates = sorted(date_paths)
                old_runs.append([sorted_dates[0], date_paths[sorted_dates[0]]])
        oldest_date = sorted([x[0] for x in old_runs])[0]
        for _date, _path in old_runs:
            if _date <= oldest_date:
                logging.info("Eliminando: " + _path)
                shutil.rmtree(_path, ignore_errors=True)
        t, u, f = shutil.disk_usage(backup_destination)
        free_space = f / 1073741824

    ### move (or delete for /arw/data) original_destination to backup destination
    # XX Gb minimo de espacio libre
    min_free_space = 80 
    t, u, f = shutil.disk_usage(original_destination)
    free_space = f / 1073741824
    while free_space < min_free_space:
        old_runs = []
        for type_run in ["run", "rap", "data"]:
            date_paths = {}
            for dir in glob(original_destination + "/" + type_run + "/*/"):
                try:
                    dir_date = datetime.strptime(dir.split("/")[-2], "%Y%m%d-%H")
                except:
                    continue
                date_paths[dir_date] = dir
            if date_paths:
                sorted_dates = sorted(date_paths)
                old_runs.append([sorted_dates[0], date_paths[sorted_dates[0]]])
        oldest_date = sorted([x[0] for x in old_runs])[0]
        for _date, _path in old_runs:
            if _date <= oldest_date:
                if _path.startswith(original_destination + "/" + "data"):
                    logging.info("Eliminando: " + _path)
                    shutil.rmtree(_path, ignore_errors=True)
                else:
                    logging.info("Moviendo: " + _path)
                    shutil.rmtree(os.path.join(backup_destination, type_run, os.path.basename(_path)),
                                  ignore_errors=True)
                    type_run = _path.split("/")[2]
                    #shutil.move(os.path.dirname(_path), backup_destination + "/" + type_run + "/")
                    fecha = _path.split("/")[3]
                    borrarfolder =  backup_destination + "/" + type_run + "/" + fecha
                    if os.path.exists(borrarfolder):
                       os.system("rm -rf " + borrarfolder)
                    shutil.move(os.path.dirname(_path), os.path.join(backup_destination,type_run))
        t, u, f = shutil.disk_usage(original_destination)
        free_space = f / 1073741824


def free_spaces_before_post(settings):

#    backup_destination = "/disco2/output/postprocess/"
  backup_destination1 = settings['globals']['post_dir']
#  backup_destination2 = settings['globals']['run_dir'].replace(settings['globals']['base_dir'],settings['globals']['backup_destination'])
  backup_destination2 = "/disco1/run/" 

  for backup_destination in [backup_destination1, backup_destination2]:

    ### delete in backup destination
    # XX Gb minimo de espacio libre
    min_free_space = 120
    t, u, f = shutil.disk_usage(backup_destination)
    free_space = f/1073741824

    while free_space < min_free_space:
   #      print (free_space)
      date_paths = {}
      old_runs = []
      for dir in glob(backup_destination+"/*"):
        try:
           dir_date = datetime.strptime(dir.split("/")[-1], "%Y%m%d-%H")
        except:
           continue
        date_paths[dir_date] = dir
      if date_paths:
           sorted_dates = sorted(date_paths)
           old_runs.append([sorted_dates[0], date_paths[sorted_dates[0]]])

      oldest_date = sorted([x[0] for x in old_runs])[0]
      for _date, _path in old_runs:
        if _date <= oldest_date:
           #print("Eliminando: " + _path)
            logging.info("Eliminando: " + _path)
            shutil.rmtree(_path, ignore_errors=True)
      t, u, f = shutil.disk_usage(backup_destination)
      free_space = f / 1073741824

#def force_symlink(file1, file2):
 #   try:
 #       os.symlink(file1, file2)
 #   except OSError, e:
 #       if e.errno == errno.EEXIST:
 #           os.remove(file2)
 #           os.symlink(file1, file2)
