#!/bin/bash
error_detect=0
err_report() { echo "Error on line $1" ; error_detect=1 ; } ; trap 'err_report $LINENO' ERR
################################################################################
# "dc"  ssh-key bei hetzner Hinterlegen
# hcloud nach /opt/dc/external ???
# yq     nach /opt/dc/external  
# hcloud context create  dc  # creates: cat ~/.config/hcloud/cli.toml 
# hcloud image    list
# hcloud location list
# hcloud type     list
# hname="tescht"
################################################################################
DC_HOST="test-host"
SERVER="karl"
PROJECT="test-project"

if [ "$1" = "" -o "$1" = "create" ] ; then 
  dc config create host ${DC_HOST} test.intra # create new host with hostname test.intra 
  dc vserver assign      ${DC_HOST} hcloud "name=$SERVER" "init.type=cx11" "init.image=ubuntu-22.04" "init.location=fsn1" "init.ssh-key=dc"
  #dc config yq host     ${DC_HOST} "-i '.host.vserver.hcoud.name = "hugo"'" 
  dc vserver create      ${DC_HOST}            # create assigned hetzner cloud server
  dc vserver install     ${DC_HOST}            # install docker an do a dist-upgrade 
  dc vserver reboot      ${DC_HOST}            # reboot and and wait until docker ist available
  # install, start and test filebrowser template project for the host
  dc config create project ${PROJECT} ${DC_HOST} filebrowser /root/dc-projects/${PROJECT}
  dc -p ${PROJECT} up                         # start project service
  ip=$(dc-yq '.hosts.'${DC_HOST}'.hostname' ${MDE_DC_YAML})
  port=$( dc-yq '.projects.'${PROJECT}'.compose.services.filebrowser.ports.[0].published'  ${MDE_DC_YAML} )
  sleep 1
  netcat -vz $ip $port
fi
if [ "$1" = "" -o "$1" = "delete" ] ; then 
  dc -p ${PROJECT} rm                         # shutdown project service
  dc config delete project ${PROJECT}         # delete project definition
  dc vserver delete         ${DC_HOST}         # delete assigned Hetzner cloud server
  dc config delete host    ${DC_HOST}         # delete host definition
  echo "error_detect=$error_detect"
fi
exit $error_detect

