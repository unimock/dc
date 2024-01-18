#!/bin/bash

cd
mv dc dc-orig
rm -R            dc-temp
cp -Rf  dc-orig  dc-temp
ln -s dc-temp dc
rm -r            dc-temp/logs/*

list=$(find dc-temp -name host.yml)
for i in $list ; do
  sed -i "s|^host:|node:|g"  $i
  sed -i "s| host | node |g" $i
  mv $i `dirname $i`/node.yml
done 
mv dc-temp/hosts dc-temp/nodes

list=$(find dc-temp -name dc-project.yml)
for i in $list ; do
  sed -i "s| host: | node: |g"  $i
done 

grep -r host dc-temp | grep -v "hostname" | grep host

rm -rvf .dc/var
sed -i "s|hosts|nodes|g" .dc/etc/config
. /opt/dc/funcs/bash-completion
dc config rebuild



#
# dc package itself:
#

rm -Rf          /opt/dc-temp
cp -r   /opt/dc /opt/dc-temp  
rm -r           /opt/dc-temp/.git /opt/dc-temp/updates/update-*

/opt/dc/bin/replace-helper /opt/dc-temp/ "hostname" "HOSTNAME"
/opt/dc/bin/replace-helper /opt/dc-temp/ "host" "node"
/opt/dc/bin/replace-helper /opt/dc-temp/ "HOSTNAME" "hostname"

mv /opt/dc-temp/bin/dc-host /opt/dc-temp/bin/dc-node
mv /opt/dc-temp/templates/create/host /opt/dc-temp/templates/create/node 
