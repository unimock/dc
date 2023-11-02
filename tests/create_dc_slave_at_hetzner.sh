#!/bin/bash
error_detect=0
err_report() { echo "Error on line $1" ; error_detect=1 ; } ; trap 'err_report $LINENO' ERR
################################################################################
# dc-hcloud context create  dc  # creates: ~/.config/hcloud/cli.toml 
# dc-hcloud ssh-key create --name dc --public-key-from-file dc/hosts/id_ed25519.pub
################################################################################
DC_HOST="test-host"
SERVER="karl"
PROJECT="test-project"

. /opt/dc/etc/config

if [ "$1" = "" -o "$1" = "create" ] ; then
  dc host    ${DC_HOST} config  create test.intra dc  # create new host definition with hostname test.intra and type "dc"
  dc host    ${DC_HOST} vserver assign hcloud "name=$SERVER" "init.type=cx11" "init.image=ubuntu-22.04" "init.location=fsn1" "init.ssh-key=dc"
  dc host    ${DC_HOST} vserver create         # create assigned hetzner cloud server
# dc host    ${DC_HOST} vserver rebuild
  dc host    ${DC_HOST} vserver install        # install docker an do a dist-upgrade 
  dc host    ${DC_HOST} reboot  wait dock,dc   # reboot and and wait until docker ist available
  # install, start and test filebrowser template project for the host
  dc project ${PROJECT} config  create ${DC_HOST} filebrowser ${MDE_DC_PROJ_DIR}/${PROJECT}
  dc -p ${PROJECT} up                       # start project service
  ip=$(dc-yq '.hosts.'${DC_HOST}'.hostname' ${MDE_DC_YAML})
  port=$( dc-yq '.projects.'${PROJECT}'.compose.services.filebrowser.ports.[0].published'  ${MDE_DC_YAML} )
  sleep 1
  netcat -vz $ip $port
fi
if [ "$1" = "" -o "$1" = "delete" ] ; then 
  dc -p ${PROJECT} rm                        # shutdown project service
  dc project ${PROJECT} config  delete       # delete project definition
  dc host    ${DC_HOST} vserver delete       # delete assigned Hetzner cloud server
  dc host    ${DC_HOST} config  delete       # delete host definition
  dc hcloud server list
  echo "error_detect=$error_detect"
fi
exit $error_detect

