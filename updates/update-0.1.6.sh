#!/bin/bash

. /opt/dc/etc/config


mkdir /xxx
tar -czvf /xxx/x.tgz ${MDE_DC_HOST_DIR}/*


list=$(find ${MDE_DC_HOST_DIR} -name "host.yml")

for i in $list ; do
  dc-yq -i 'del(.host.hostname)' $i
done
dc config rebuild
exit 0

