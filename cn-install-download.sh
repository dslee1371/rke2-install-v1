#!/bin/bash

# External file reference
CONFIG_FILE="./group_vars/all/variables.yaml"

# Variables from an external file
DIR_PATH=$(/usr/local/bin/yq e '.LOCAL_PATH.BASE' $CONFIG_FILE)

# Input Version 
VERSION=v0.4

curl -o $DIR_PATH/cn-install-file-$VERSION.tar.gz -u cnstudio:cnstudio2024\!\! https://nexus.dspace.kt.co.kr/repository/raw-dspace-host/cnstudio/cn-install-file-$VERSION.tar.gz  > $DIR_PATH/cn-install-$VERSION-download.log 2>&1 &

