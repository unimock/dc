#!/bin/bash
error_detect=0
err_report() { echo "Error on line $1" ; error_detect=1 ; } ; trap 'err_report $LINENO' ERR
################################################################################
# dc-hcloud context create  dc  # creates: ~/.config/hcloud/cli.toml 
# dc-hcloud ssh-key create --name dc --public-key-from-file dc/nodes/id_ed25519.pub
################################################################################
source ${HOME}/.dc/etc/config
HOST="test"
VSERVER="test"
APP="test-app"
TEMPL="kvm"

if [ "$1" = "" -o "$1" = "create" ] ; then
  dc node    $HOST config  create test.intra dc   # create new node definition with hostname test.intra and type "dc"
  dc node    $HOST vserver assign $VSERVER $TEMPL # assign virtual server to node
  #dc node   $HOST vserver rebuild                # only useful for hetznercloud
  dc node    $HOST vserver create                 # create assigned hetzner cloud server
  dc node    $HOST state                          # check if node returns dc
  # install, start and test hello-world template app for the node
  dc app $APP config create $HOST hello-world ${MDE_DC_APP_DIR}/$APP
  dc -p ${APP} up                             # start app service
  sleep 2
fi
if [ "$1" = "" -o "$1" = "test" ] ; then
  ip=$(dc node $HOST ip)
  port=$( dc-yq '.apps.'$APP'.compose.services.hello-world.ports.[0].published'  ${MDE_DC_YAML} )
  netcat -vz $ip $port
fi
if [ "$1" = "" -o "$1" = "delete" ] ; then 
  dc -p $APP rm                               # shutdown app service
  dc app $APP  config  delete             # delete app definition
  dc node    $HOST vserver delete             # delete assigned virtual server
  dc node    $HOST config  delete             # delete node definition
  echo "error_detect=$error_detect"
fi
exit $error_detect

