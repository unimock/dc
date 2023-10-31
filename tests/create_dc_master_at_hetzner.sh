#!/bin/bash
error_detect=0
err_report() { echo "Error on line $1" ; error_detect=1 ; } ; trap 'err_report $LINENO' ERR
################################################################################
# dc-hcloud context create  dc  # creates: ~/.config/hcloud/cli.toml 
# dc-hcloud ssh-key create --name dc --public-key-from-file dc/hosts/id_ed25519.pub
################################################################################
DC_HOST="tmaster"
SERVER="hugo"

. /opt/dc/etc/config

if [ "$1" = "" -o "$1" = "create" ] ; then 
  dc config create host ${DC_HOST} test.intra dock # create new host with hostname test.intra and type "dock" 
  dc vserver assign     ${DC_HOST} hcloud "name=$SERVER" "init.type=cx11" "init.image=ubuntu-22.04" "init.location=fsn1" "init.ssh-key=dc"
  dc vserver create     ${DC_HOST}            # create assigned hetzner cloud server
  dc vserver install    ${DC_HOST}            # install docker an do a dist-upgrade 
  dc vserver reboot     ${DC_HOST}            # reboot and and wait until docker ist available
  IP=$(dc-yq '.hosts.'${DC_HOST}'.hostname' ${MDE_DC_YAML})
  echo "IP=$IP"
  ssh ${DC_HOST} git clone https://github.com/unimock/dc.git /opt/dc
  ssh ${DC_HOST} /opt/dc/bin/dc-install
  ssh ${DC_HOST} /opt/dc/bin/dc-install
  # lets play around on the new dc cluster manager
  ssh ${DC_HOST} 'cat /root/dc/hosts/id_ed25519.pub > /root/.ssh/authorized_keys'
  ssh ${DC_HOST} dc config create host hugo $IP dc
  ssh ${DC_HOST} dc ls hosts
  ssh ${DC_HOST} dc config create project filebrowser hugo filebrowser /root/dc/projects/filebrowser
  ssh ${DC_HOST} dc -p filebrowser up
  ssh ${DC_HOST} dc ls projects --inspect
  PORT=$(ssh ${DC_HOST} dc-yq '.projects.filebrowser.compose.services.filebrowser.ports.[0].published')
  sleep 1
  netcat -vz $IP $PORT
fi
if [ "$1" = "" -o "$1" = "delete" ] ; then 
  ssh ${DC_HOST} dc -p filebrowser rm          # stop and remove 
  ssh ${DC_HOST} dc config delete project filebrowser
  ssh ${DC_HOST} dc config delete host hugo
  dc vserver delete        ${DC_HOST}         # delete assigned Hetzner cloud server
  dc config delete host    ${DC_HOST}         # delete host definition
  dc vserver list
  echo "error_detect=$error_detect"
fi
exit $error_detect

