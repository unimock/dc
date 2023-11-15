#!/bin/bash
error_detect=0
err_report() { echo "Error on line $1" ; error_detect=1 ; } ; trap 'err_report $LINENO' ERR
################################################################################
# dc-hcloud context create  dc  # creates: ~/.config/hcloud/cli.toml 
# dc-hcloud ssh-key create --name dc --public-key-from-file dc/hosts/id_ed25519.pub
################################################################################

HOST="test"
VSERVER="test"
SLAVE="dc-slave"
TEMPL="kvm"

if [ "$1" = "" -o "$1" = "create" ] ; then
  dc host $HOST config create test.intra dock  # create new host definition with hostname test.intra and type "dc"
  dc host $HOST vserver assign $VSERVER $TEMPL # assign virtual server to host
  #dc host $HOST vserver rebuild               # only useful for hetznercloud
  dc host $HOST vserver create                 # create assigned hetzner cloud server
  dc host $HOST state                          # check if host returns dc
  IP=$(dc-yq '.hosts.'$HOST'.fqdn' ${MDE_DC_YAML})
  echo "IP=$IP"
  ssh $HOST git clone https://github.com/unimock/dc.git /opt/dc
  ssh $HOST /opt/dc/bin/dc-install
  ssh $HOST /opt/dc/bin/dc-install
  # lets play around on the new dc cluster manager
  ssh $HOST 'cat /root/dc/hosts/id_ed25519.pub > /root/.ssh/authorized_keys'
  ssh $HOST dc host $SLAVE config create $IP dc
  ssh $HOST dc ls hosts --inspect
  ssh $HOST dc project hello-world config create $SLAVE hello-world /root/dc/projects/hello-world
  ssh $HOST dc -p hello-world up
fi
if [ "$1" = "" -o "$1" = "test" ] ; then
  ssh $HOST dc ls projects --inspect
  PORT=$(ssh $HOST dc-yq '.projects.hello-world.compose.services.hello-world.ports.[0].published')
  sleep 1
  netcat -vz $IP $PORT
fi
if [ "$1" = "" -o "$1" = "delete" ] ; then 
  ssh $HOST dc -p hello-world rm                 # stop and remove hello-world project services
  ssh $HOST dc project hello-world config delete # remove hello-world project definition
  ssh $HOST dc host $SLAVE config delete         # delete host config definition
  dc host $HOST vserver delete                   # delete assigned Hetzner cloud server
  dc host $HOST config  delete                   # delete host definition
  echo "error_detect=$error_detect"
fi
exit $error_detect

