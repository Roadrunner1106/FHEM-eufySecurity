# Deploy Scripts
The deploy directory contains scripts to synchronize extended changes between the local repository and the installation.
## deploy2server.sh
Changes in the local repository are copied to the local installation. If a file in the local installation is newer than in the repository, it is not copied and a warning is issued.
## deploy2repro.sh
Changes in the local installation are copied to the local repository. If a file in the local repository is newer than in the installation, it is not copied and a warning is issued.

## diff.sh
Compares the models of the local installation with the modules from the repository