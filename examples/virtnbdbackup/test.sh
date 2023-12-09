#!/bin/bash
error_detect=0
err_report() { echo "Error on line $1" ; error_detect=1 ; } ; trap 'err_report $LINENO' ERR
source ${HOME}/.dc/etc/config
HOST="test"
VSERVER="test"
TEMPL="/opt/dc/examples/virtnbdbackup/vserver.yml"
BDIR="~/virtnbdbackup-test"

if [ "$1" = "" -o "$1" = "create" ] ; then
  dc host    $HOST config  create test.intra sshd  # create new host definition with hostname test.intra and type "dc"
  dc host    $HOST vserver assign $VSERVER $TEMPL # assign virtual server to host
  dc host    $HOST vserver create                 # create assigned hetzner cloud server
  sudo virtnbdbackup  -d test -l auto -o $BDIR
  virsh checkpoint-list test
fi

#if [ "$1" = "" -o "$1" = "del" ] ; then 
#  sudo rm -rvf $BDIR
#fi

if [ "$1" = "" -o "$1" = "backup" ] ; then
  ssh test touch /root/MEIN_TEST
  sudo virtnbdbackup  -d test -l auto -o $BDIR
  virsh checkpoint-list test
fi

#if [ "$1" = "" -o "$1" = "full" ] ; then 
#  sudo virtnbdbackup  -d test -l full -o $BDIR
#  virsh checkpoint-list test
#fi

#if [ "$1" = "" -o "$1" = "inc" ] ; then 
#  sudo virtnbdbackup  -d test -l inc -o $BDIR
#  virsh checkpoint-list test
#fi

if [ "$1" = "" -o "$1" = "verify" ] ; then 
  sudo virtnbdrestore -i $BDIR -o verify
  virsh checkpoint-list test
fi

if [ "$1" = "" -o "$1" = "restore" ] ; then
  name="test"
  virsh destroy  $name
  virsh undefine $name --remove-all-storage --checkpoints-metadata --snapshots-metadata
  sudo ls /var/lib/dc-kvm/
  sudo virtnbdrestore -D -N $name -i $BDIR -o /var/lib/dc-kvm
  # wenn -N nicht angegeben, dann name: restore_test
  sudo sh -c 'rm -v /var/lib/dc-kvm/vmconfig.virtnbdbackup.*.xml'
  virsh start $name
  dc host $name state wait sshd
  sudo rm -rf $BDIR
fi

if [ "$1" = "" -o "$1" = "test" ] ; then
  ssh test ls -la /root/MEIN_TEST
  if [ "$?" != "0" ] ; then
    error_detect=1
  fi
fi

if [ "$1" = "" -o "$1" = "delete" ] ; then 
  dc host    $HOST vserver delete                 # delete assigned virtual server
  dc host    $HOST config  delete                 # delete host definition
  sudo rm -rf $BDIR
  echo "error_detect=$error_detect"
fi
exit $error_detect

