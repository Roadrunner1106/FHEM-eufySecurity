#!/bin/bash

REPRO=../
REPRO_SRC=../opt/fhem/FHEM/
REPRO_DST=/opt/fhem/FHEM/

FILES=("73_eufySecurity.pm 73_eufyCamera.pm 73_eufyStation.pm")

for f in $FILES; do
	cp -u $REPRO_DST$f $REPRO_SRC$f
done