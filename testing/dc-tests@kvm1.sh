#!/bin/bash

. /opt/dc/funcs/script_funcs

sf_start

error_detect=0
err_report() { printf "!\n! Error on line $1\n!\n" ; error_detect=1 ; } ; trap 'err_report $LINENO' ERR

HOST="test"              # local dc host name
VSERVER="test@kvm1"      # machine name @ kvm server
SLAVE="dc-slave"         # remote dc host name
TEMPL="kvm"              # vserver template which includes kvm-/cloud-config-/dc-install settings 

if [ "$1" = "" -o "$1" = "create" ] ; then
  dc host $HOST config create test.intra dock  # create new host definition with hostname test.intra and type "dc"
  dc host $HOST vserver assign $VSERVER $TEMPL # assign virtual server to host
  dc host $HOST vserver create                 # create assigned hetzner cloud server
  dc host $HOST state                          # check if host returns dc
  # install dc
  ssh $HOST git clone https://github.com/unimock/dc.git /opt/dc
  ssh $HOST /opt/dc/bin/dc-install --force
  ssh $HOST 'cat /root/dc/hosts/id_ed25519.pub >> /root/.ssh/authorized_keys'
fi
if [ "$1" = "" -o "$1" = "test" ] ; then
  IP=$(dc-yq '.hosts.'$HOST'.fqdn' ${MDE_DC_YAML})
  echo "IP=$IP"
  # lets play around on the new dc cluster manager
  ssh $HOST dc host $SLAVE config create $IP dc
  state=$(ssh $HOST dc host $SLAVE state)
  if [ "$state" != "dc" ] ; then
    sf_set_error
  fi
  ssh $HOST dc project hello-world config create $SLAVE hello-world /root/dc/projects/hello-world
  ssh $HOST dc -p hello-world up
  #ssh $HOST dc ls projects --inspect
  PORT=$(ssh $HOST dc-yq '.projects.hello-world.compose.services.hello-world.ports.[0].published')
  sleep 1
  netcat -vz $IP $PORT
  if [ "$?" != "0" ] ; then
    sf_set_error
  fi
  ssh $HOST dc -p hello-world rm                 # stop and remove hello-world project services
  ssh $HOST dc project hello-world config delete # remove hello-world project definition
  ssh $HOST dc host $SLAVE config delete         # delete host config definition
fi
if [ "$1" = "" -o "$1" = "delete" ] ; then
  dc host $HOST vserver delete                   # delete assigned Hetzner cloud server
  dc host $HOST config  delete                   # delete host definition
  echo "error_detect=$error_detect"
fi
if [ "$error_detect" != "0" ] ; then
  sf_set_error
fi
sf_end

