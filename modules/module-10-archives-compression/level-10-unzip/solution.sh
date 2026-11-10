#!/bin/bash
unzip -l upload.zip
unzip -j -n upload.zip '*.csv' -x '__MACOSX/*' -d import
ls -la import
