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
import os
from dateutil.relativedelta import relativedelta


def wps(settings):
    """
    Namelist para WPS
    """
    # open template
    with open(os.path.join(os.path.dirname(__file__), 'wps.template'), 'r') as infile:
        wps_file = infile.read()

    # set the variables inside namelist
    wps_file = wps_file.format(
        start_date=settings['globals']['start_date'].strftime("%Y-%m-%d"),
        start_hour=settings['globals']['start_date'].strftime("%H"),
        end_date=settings['process']['end_date'].strftime("%Y-%m-%d"),
        end_hour=settings['process']['end_date'].strftime("%H"),
        end_date_d01=settings['process']['end_date_d01'].strftime("%Y-%m-%d"),
        end_hour_d01=settings['process']['end_date_d01'].strftime("%H"),
        end_date_d02=settings['process']['end_date_d02'].strftime("%Y-%m-%d"),
        end_hour_d02=settings['process']['end_date_d02'].strftime("%H"),
        wrf_path=settings['process']['wrf_path'],
        domains=settings['process']['domains'],
        interval_seconds=settings['process']['interval_seconds'],
    )
    # save the wps.template file
    path_to_save = os.path.join(settings['globals']['run_wps_dir'], "namelist.wps")
    outfile = open(path_to_save, "w")
    outfile.writelines(wps_file)
    outfile.close()


def wrf(settings, path_to_save):
    """
    Namelist para WRF
    """
    # open template
    with open(os.path.join(os.path.dirname(__file__), 'wrf.template'), 'r') as infile:
        wrf_file = infile.read()

    # set the variables inside namelist
    wrf_file = wrf_file.format(
        start_year=settings['globals']['start_date'].strftime("%Y"),
        start_month=settings['globals']['start_date'].strftime("%m"),
        start_day=settings['globals']['start_date'].strftime("%d"),
        start_hour=settings['globals']['start_date'].strftime("%H"),
        end_year=settings['process']['end_date'].strftime("%Y"),
        end_month=settings['process']['end_date'].strftime("%m"),
        end_day=settings['process']['end_date'].strftime("%d"),
        end_hour=settings['process']['end_date'].strftime("%H"),
        end_year_d01=settings['process']['end_date_d01'].strftime("%Y"),
        end_month_d01=settings['process']['end_date_d01'].strftime("%m"),
        end_day_d01=settings['process']['end_date_d01'].strftime("%d"),
        end_hour_d01=settings['process']['end_date_d01'].strftime("%H"),
        end_year_d02=settings['process']['end_date_d02'].strftime("%Y"),
        end_month_d02=settings['process']['end_date_d02'].strftime("%m"),
        end_day_d02=settings['process']['end_date_d02'].strftime("%d"),
        end_hour_d02=settings['process']['end_date_d02'].strftime("%H"),
        domains=settings['process']['domains'],
        interval_seconds=settings['process']['interval_seconds'],
        history_interval=settings['process']['history_interval'],
    )
    # save the wrf.template file
    outfile = open(os.path.join(path_to_save, "namelist.input"), "w")
    outfile.writelines(wrf_file)
    outfile.close()


def obsproc(settings):
    """
    Namelist para Obsproc
    """
    # open template
    with open(os.path.join(os.path.dirname(__file__), 'obsproc.template'), 'r') as infile:
        obsproc_file = infile.read()

    tw_min_date = settings['globals']['start_date'] - relativedelta(hours=float(settings['assim']['time_window'])/2)
    tw_max_date = settings['globals']['start_date'] + relativedelta(hours=float(settings['assim']['time_window'])/2)

    # set the variables inside namelist
    obsproc_file = obsproc_file.format(
        start_year=settings['globals']['start_date'].strftime("%Y"),
        start_month=settings['globals']['start_date'].strftime("%m"),
        start_day=settings['globals']['start_date'].strftime("%d"),
        start_hour=settings['globals']['start_date'].strftime("%H"),
        tw_min_year=tw_min_date.strftime("%Y"),
        tw_min_month=tw_min_date.strftime("%m"),
        tw_min_day=tw_min_date.strftime("%d"),
        tw_min_hour=tw_min_date.strftime("%H"),
        tw_min_min=tw_min_date.strftime("%M"),
        tw_max_year=tw_max_date.strftime("%Y"),
        tw_max_month=tw_max_date.strftime("%m"),
        tw_max_day=tw_max_date.strftime("%d"),
        tw_max_hour=tw_max_date.strftime("%H"),
        tw_max_min=tw_max_date.strftime("%M"),
    )
    # save the obsproc.template file
    path_to_save = os.path.join(settings['globals']['run_obsproc_dir'], "namelist.obsproc")
    outfile = open(path_to_save, "w")
    outfile.writelines(obsproc_file)
    outfile.close()


def _3dvar(settings, domain):
    """
    Namelist para 3dvar
    """
    # open template
    with open(os.path.join(os.path.dirname(__file__), '3dvar_d0{}.template'.format(domain)), 'r') as infile:
        _3dvar_file = infile.read()

    tw_min_date = settings['globals']['start_date'] - relativedelta(
        hours=float(settings['assim']['time_window']) / 2)
    tw_max_date = settings['globals']['start_date'] + relativedelta(
        hours=float(settings['assim']['time_window']) / 2)

    dom=str(domain)
    # set the variables inside namelist
    _3dvar_file = _3dvar_file.format(
        start_year=settings['globals']['start_date'].strftime("%Y"),
        start_month=settings['globals']['start_date'].strftime("%m"),
        start_day=settings['globals']['start_date'].strftime("%d"),
        start_hour=settings['globals']['start_date'].strftime("%H"),
        end_year=settings['process']['end_date_d0'+dom].strftime("%Y"),
        end_month=settings['process']['end_date_d0'+dom].strftime("%m"),
        end_day=settings['process']['end_date_d0'+dom].strftime("%d"),
        end_hour=settings['process']['end_date_d0'+dom].strftime("%H"),
        tw_min_date=tw_min_date.strftime("%Y-%m-%d_%H"),
        tw_max_date=tw_max_date.strftime("%Y-%m-%d_%H"),
        history_interval=settings['process']['history_interval'],
        interval_seconds=settings['process']['interval_seconds'],
        p2e_radar2txt=settings['flags']['p2e_radar2txt'],
        p2f_goes=settings['flags']['p2f_goes'],

    )
    # save the namelist file
    path_to_save = os.path.join(settings['globals']['run_dir'], "wrfda", "da_d0"+domain, "namelist.input")
    outfile = open(path_to_save, "w")
    outfile.writelines(_3dvar_file)
    outfile.close()


def arwpost(settings, domain_to_run, path_source, path_dest, path_to_save):
    """
    Namelist para ARWpost 
    """
    # open template
    with open(os.path.join(os.path.dirname(__file__), 'arwpost.template'), 'r') as infile:
        arw_file = infile.read()
    dom=str(domain_to_run)
    # set the variables inside namelist
    arw_file = arw_file.format(
        start_year=settings['globals']['start_date'].strftime("%Y"),
        start_month=settings['globals']['start_date'].strftime("%m"),
        start_day=settings['globals']['start_date'].strftime("%d"),
        start_hour=settings['globals']['start_date'].strftime("%H"),
        end_year=settings['process']['end_date_d0'+dom].strftime("%Y"),
        end_month=settings['process']['end_date_d0'+dom].strftime("%m"),
        end_day=settings['process']['end_date_d0'+dom].strftime("%d"),
        end_hour=settings['process']['end_date_d0'+dom].strftime("%H"),
        domain=domain_to_run,
        path_in=path_source,
        path_out=path_dest,
        interval_seconds=settings['process']['interval_seconds'],
    )
    # save the wrf.template file
    outfile = open(os.path.join(path_to_save, "namelist.ARWpost"), "w")
    outfile.writelines(arw_file)
    outfile.close()

