#!/bin/bash
source ${HOME}/.dc/etc/config

list=$( find ${MDE_DC_HOST_DIR} -name "host.yml"  )
for FI in $list ; do
  dc-yq -i 'del( .host.vserver)' $FI
  # rename hostname with fqdn
  sed -i "s/^  hostname:/  fqdn:/g" $FI
  #dc-yq -i '.host.fqdn = .host.hostname | del(.host.hostname)' $FI
  sed -i '/# if host is homed in Hetzner Cloud/d' $FI
done

dc config rebuild

exit 0

