#!/bin/bash
error_detect=0
err_report() { echo "Error on line $1" ; error_detect=1 ; } ; trap 'err_report $LINENO' ERR
################################################################################
# dc-hcloud context create  dc  # creates: ~/.config/hcloud/cli.toml 
# dc-hcloud ssh-key create --name dc --public-key-from-file dc/nodes/id_ed25519.pub
################################################################################
source ${HOME}/.dc/etc/config
HOST="test"

dc node    $HOST config  create test.intra sshd  # create new node definition with hostname test.intra and type "dc"

VSERVER="test" ; TEMPL="kvm"                     #
dc node    $HOST vserver assign $VSERVER $TEMPL  # assign local kvm machine to node
dc node    $HOST vserver create                  # create local kvm machine
ssh $HOST hostname ; ssh $HOST uptime            # login into the new machine
dc node    $HOST vserver delete                  # delete local kvm machine

VSERVER="test@kvm1" ; TEMPL="kvm"                # 
dc node    $HOST vserver assign $VSERVER $TEMPL  # assign remote kvm machine @kvm1 to node
dc node    $HOST vserver create                  # create remote kvm machine @kvm1 server
ssh $HOST hostname ; ssh $HOST uptime            # login into the new machine
dc node    $HOST vserver delete                  # delete remote kvm machine @kvm1 server

#VSERVER="test" ; TEMPL="hcloud"
#dc node    $HOST vserver assign $VSERVER $TEMPL  # assign remote hetzner cloud machine to node
#dc node    $HOST vserver create                  # create remote hetzner cloud machine
#ssh $HOST hostname ; ssh $HOST uptime            # login into the new hetzner cloud machine

dc node    $HOST config  delete                  # delete node definition
echo "error_detect=$error_detect"
exit $error_detect

