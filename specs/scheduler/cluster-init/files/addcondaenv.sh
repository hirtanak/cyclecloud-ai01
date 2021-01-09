#!/bin/bash

source ${HOMEDIR}/anaconda/etc/profile.d/conda.sh
conda create -n $1 python=3.7 ipython ipykernel -y 
conda activate $1
ipython kernel install --user --name=$1 --display-name=$1
