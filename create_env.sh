#!/bin/bash 
echo "This script create a new python environment with all required packages"

echo "firs step install the virtualenv library"
pip3 install virtualenv
echo "creating a new virtual environment"
python3 -m venv wrf_env
echo "activating the virtual env"
source ./wrf_env/bin/activate
echo "installing required python libs"
pip3 install -r requirements.txt
echo "finished"

