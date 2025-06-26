#!/bin/bash

TAGS=$@

if [ ! -z $TAGS ]
then
    ansible-playbook  playbook.yml -t "$TAGS" -e "@vars/external-vars.server.yaml"
else
    ansible-playbook  playbook.yml -e "@vars/external-vars.server.yaml"
fi
