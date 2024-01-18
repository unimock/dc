#!/bin/bash
error_detect=0
err_report() { echo "Error on line $1" ; error_detect=1 ; } ; trap 'err_report $LINENO' ERR
################################################################################
# dc-hcloud context create  dc  # creates: ~/.config/hcloud/cli.toml 
# dc-hcloud ssh-key create --name dc --public-key-from-file dc/nodes/id_ed25519.pub
################################################################################

HOST="test"
VSERVER="test"
SLAVE="dc-slave"
TEMPL="hcloud"

if [ "$1" = "" -o "$1" = "create" ] ; then
  dc node $HOST config create test.intra dock  # create new node definition with hostname test.intra and type "dc"
  dc node $HOST vserver assign $VSERVER $TEMPL # assign virtual server to node
  #dc node $HOST vserver rebuild               # only useful for hetznercloud
  dc node $HOST vserver create                 # create assigned hetzner cloud server
  dc node $HOST state                          # check if node returns dc
  ssh $HOST git clone https://github.com/unimock/dc.git /opt/dc
  ssh $HOST /opt/dc/bin/dc-install --force
  ssh $HOST 'cat /root/dc/nodes/id_ed25519.pub >> /root/.ssh/authorized_keys'
fi
if [ "$1" = "" -o "$1" = "test" ] ; then
  IP=$(dc node $HOST)
  echo "IP=$IP"
  # lets play around on the new dc cluster manager
  ssh $HOST dc node $SLAVE config create $IP dc
  ssh $HOST dc ls nodes --inspect
  ssh $HOST dc project hello-world config create $SLAVE hello-world /root/dc/projects/hello-world
  ssh $HOST dc -p hello-world up
  ssh $HOST dc ls projects --inspect
  PORT=$(ssh $HOST dc-yq '.projects.hello-world.compose.services.hello-world.ports.[0].published')
  sleep 1
  netcat -vz $IP $PORT
fi
if [ "$1" = "" -o "$1" = "delete" ] ; then 
  ssh $HOST dc -p hello-world rm                 # stop and remove hello-world project services
  ssh $HOST dc project hello-world config delete # remove hello-world project definition
  ssh $HOST dc node $SLAVE config delete         # delete node config definition
  dc node $HOST vserver delete                   # delete assigned Hetzner cloud server
  dc node $HOST config  delete                   # delete node definition
  echo "error_detect=$error_detect"
fi
exit $error_detect

