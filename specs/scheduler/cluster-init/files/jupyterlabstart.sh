#!/usr/bin/bash



source /shared//home/azureuser/anaconda/etc/profile.d/conda.sh && /home/azureuser/anaconda/condabin/conda activate ${ANACONDAENVNAME}
/home/${CUSER}/anaconda/envs/${ANACONDAENVNAME}/bin/jupyter-lab --allow-root --config=${HOMEDIR}/.jupyter/jupyter_notebook_config.py
