#!/bin/bash
source ${HOME}/.dc/etc/config

list=$( find ${MDE_DC_PROJ_DIR} -name "dc-project.yml"  )
mkdir -p /xxx
tar -cvf /xxx/save-0.6.0.tar $list
for FI in $list ; do
  echo $FI
  dc-yq -i '.project.run_level = 5' $FI
  #dc-yq -i 'del( .host.vserver)' $FI
  # rename hostname with fqdn
  #sed -i "s/^  hostname:/  fqdn:/g" $FI
  #dc-yq -i '.host.fqdn = .host.hostname | del(.host.hostname)' $FI
  #sed -i '/# if host is homed in Hetzner Cloud/d' $FI
done

dc config rebuild

exit 0

