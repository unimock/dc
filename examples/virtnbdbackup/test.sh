#!/bin/bash
error_detect=0
err_report() { echo "Error on line $1" ; error_detect=1 ; } ; trap 'err_report $LINENO' ERR
source ${HOME}/.dc/etc/config
DOMAIN="test1"
TEMPL="/opt/dc/examples/virtnbdbackup/vserver.yml"
BDIR="~/virtnbdbackup-test"

KC="usb"
#KC=""

_kc_backup() {
  if [ "$KC" != "usb" ] ; then
    return
  fi
  BDIR="/backup/virtnbd/$DOMAIN"
  sudo /opt/kc/bin/kc-backup $*
  return $?
}

if [ "$1" = "" -o "$1" = "create" ] ; then

      

  dc node tvirt1 config  create tvirt1.intra sshd  # create new node definition with hostname test.intra and type "dc"
  dc node tvirt1 vserver assign $DOMAIN $TEMPL  # assign virtual server to node
  dc-yq -i '.cloud-config.hostname = "'tvirt1'"' $MDE_DC_HOST_DIR/tvirt1/vserver.yml
  dc node tvirt1 vserver create                  # create assigned machine
  sudo smartctl -s standby,off /dev/sda

  _kc_backup mount
  sudo rm -rf $BDIR
  #sudo virtnbdbackup  -d $DOMAIN -l auto -o $BDIR    # create first backup
  _kc_backup umount
  virsh checkpoint-list $DOMAIN
fi

if [ "$1" = "10g" ] ; then
  ssh tvirt1 'head -c 10G /dev/urandom > /root/sample.txt'
fi

if [ "$1" = "" -o "$1" = "backup" ] ; then
  ssh tvirt1 touch /root/MEIN_TEST                  # change someting
  _kc_backup mount
  time sudo virtnbdbackup  -d $DOMAIN -l auto -o $BDIR    # do second backup
  _kc_backup umount
  virsh checkpoint-list $DOMAIN
fi

#if [ "$1" = "" -o "$1" = "full" ] ; then 
#  sudo virtnbdbackup  -d $DOMAIN -l full -o $BDIR
#  virsh checkpoint-list $DOMAIN
#fi

#if [ "$1" = "" -o "$1" = "inc" ] ; then 
#  sudo virtnbdbackup  -d $DOMAIN -l inc -o $BDIR
#  virsh checkpoint-list $DOMAIN
#fi

if [ "$1" = "shutdown" ] ; then
  /opt/kc/bin/kc down $DOMAIN
fi

if [ "$1" = "" -o "$1" = "verify" ] ; then
  _kc_backup mount
  sudo virtnbdrestore -i $BDIR -o verify
  _kc_backup umount
  virsh checkpoint-list $DOMAIN
fi

if [ "$1" = "" -o "$1" = "restore" ] ; then
  /opt/kc/bin/kc rm $DOMAIN
  sudo ls /var/lib/dc-kvm/
  _kc_backup mount
  sudo virtnbdrestore -D -N $DOMAIN -i $BDIR -o /var/lib/dc-kvm
  _kc_backup umount

  sudo smartctl -s standby,now /dev/sda
  # wenn -N nicht angegeben, dann name: restore_test
  sudo sh -c 'rm -v /var/lib/dc-kvm/vmconfig.virtnbdbackup.*.xml'
  /opt/kc/bin/kc up $DOMAIN
  dc node tvirt1 state wait sshd
fi

if [ "$1" = "" -o "$1" = "test" ] ; then
  ssh tvirt1 ls -la /root/MEIN_TEST
  if [ "$?" != "0" ] ; then
    error_detect=1
  fi
fi

if [ "$1" = "" -o "$1" = "delete" ] ; then 
  dc node tvirt1 vserver delete                 # delete assigned virtual server
  dc node tvirt1 config  delete                 # delete node definition
  echo "error_detect=$error_detect"
fi
exit $error_detect

