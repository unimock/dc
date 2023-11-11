#!/bin/bash
error_detect=0
err_report() { echo "Error on line $1" ; error_detect=1 ; } ; trap 'err_report $LINENO' ERR
################################################################################
# dc-hcloud context create  dc  # creates: ~/.config/hcloud/cli.toml 
# dc-hcloud ssh-key create --name dc --public-key-from-file dc/hosts/id_ed25519.pub
################################################################################
source ${HOME}/.dc/etc/config
HOST="test"
VSERVER="karl"
PROJECT="test-project"
TEMPL="kvm"

if [ "$1" = "" -o "$1" = "create" ] ; then
  dc host    $HOST config  create test.intra dc   # create new host definition with hostname test.intra and type "dc"
  dc host    $HOST vserver assign $VSERVER $TEMPL # assign virtual server to host
  #dc host   $HOST vserver rebuild                # only useful for hetznercloud
  dc host    $HOST vserver create                 # create assigned hetzner cloud server
  dc host    $HOST state                          # check if host returns dc
  # install, start and test filebrowser template project for the host
  dc project $PROJECT config create $HOST filebrowser ${MDE_DC_PROJ_DIR}/$PROJECT
  dc -p ${PROJECT} up                             # start project service
  sleep 2
  ip=$(dc-yq '.hosts.'$HOST'.fqdn' ${MDE_DC_YAML})
  port=$( dc-yq '.projects.'$PROJECT'.compose.services.filebrowser.ports.[0].published'  ${MDE_DC_YAML} )
  sleep 1
  netcat -vz $ip $port
fi
if [ "$1" = "" -o "$1" = "delete" ] ; then 
  dc -p $PROJECT rm                               # shutdown project service
  dc project $PROJECT config  delete              # delete project definition
  dc host    $HOST vserver delete                 # delete assigned virtual server
  dc host    $HOST config  delete                 # delete host definition
  echo "error_detect=$error_detect"
fi
exit $error_detect

