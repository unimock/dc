#!/bin/bash

cd /root
/opt/dc/bin/replace-helper dc/batch/   '\-h'
/opt/dc/bin/replace-helper dc/config/  '\-h'
/opt/dc/bin/replace-helper dc/swarm/   '\-h'
/opt/dc/bin/replace-helper utils       '\-h'
/opt/dc/bin/replace-helper scripts     '\-h'
/opt/dc/bin/replace-helper kvm-testing '\-h'

rm -rvf .dc/var
. /opt/dc/funcs/bash-completion
dc config rebuild

exit 




cd /opt/dc
git pull
git fetch -a
git checkout rename-hosts-to-nodes



cd /root

cp -r dc dc-backup

list=$(find dc -name host.yml)
for i in $list ; do
  sed -i "s|^host:|node:|g"  $i
  sed -i "s| host | node |g" $i
  mv $i `dirname $i`/node.yml
done 
mv dc/hosts dc/nodes


list=$(find dc -name dc-project.yml)
for i in $list ; do
  sed -i "s| host: | node: |g"  $i
done 

list=$(find ./dc/batch ./utils ./scripts -type f)
for i in $list ; do
  sed -i "s|hostname|_HOSTNAME_|g"  $i
  sed -i "s|localhost|_LOCALHOST_|g" $i
  #echo "##########################################################"
  #echo "# check $i :"
  #echo "##########################################################"
  #grep "host" $i
  sed -i "s|host|node|g" $i

  sed -i "s|_HOSTNAME_|hostname|g" $i
  sed -i "s|_LOCALHOST_|localhost|g" $i
done

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
