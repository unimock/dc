#!/bin/bash
error_detect=0
err_report() { echo "Error on line $1" ; error_detect=1 ; } ; trap 'err_report $LINENO' ERR
################################################################################
# dc-hcloud context create  dc  # creates: ~/.config/hcloud/cli.toml 
# dc-hcloud ssh-key create --name dc --public-key-from-file dc/nodes/id_ed25519.pub
################################################################################
# create vserver config for Hetzner cloud
#################################################################################
# list available server types with:
# > dc-hcloud server-type list 
#VSERVER_TYPE="cx23"  # amd64
VSERVER_TYPE="cax11" # arm64
cat << EOF > /tmp/.hcloud-arm64.yml
type: hcloud
name: <vserver_name>
hcloud:
  type: ${VSERVER_TYPE}
  # dc-hcloud image list
  image: ubuntu-24.04
  #dc-hcloud location list
  location: fsn1
  #dc-hcloud ssh-key list
  ssh-key: <ssh_pub_key_name> 
dc-install:
  dc:
    - hcloud-others
    #- docker
  apt:
    #- tree
EOF
################################################################################
NODE="htest"       # local dc node name
VSERVER="htest"    # hetzner vserver name
#REM_NODE="iam"    # remote node name on NODE
REM_NODE="."       # use remote hostname as remote node name on NODE
REM_TYPE="dc"
TEMPL="/tmp/.hcloud-arm64.yml"

ADDAPPS_URL="$( cat /xxx/addapps_url 2>/dev/null)"

if [ "$1" = "" -o "$1" = "create" ] ; then
  dc node $NODE config create test.intra ${REM_TYPE}  # create new node definition
  dc node $NODE vserver assign $VSERVER $TEMPL        # assign virtual server to node
  dc node $NODE vserver create                        # create assigned hetzner cloud server
  hcloud server list
  echo "node-state: $(dc node $NODE state)"           # check current node state ($REM_TYPE)
  if [ "$ADDAPPS_URL" = "" ] ; then 
    ssh $NODE git clone https://github.com/unimock/dc.git /opt/dc
    ssh $NODE /opt/dc/bin/dc-install --force
  else
    ssh $NODE "wget -O /tmp/addapps ${ADDAPPS_URL} ; install -m 755 /tmp/addapps /usr/local/bin"
    ssh $NODE "addapps install dc-env md-exec difft yq ; addapps ls"
  fi
fi
if [ "$1" = "" -o "$1" = "test" ] ; then
  IP=$(dc node $NODE ip)
  echo "IP=$IP"
  # lets play around on the new dc cluster manager
  ssh $NODE dc node $REM_NODE config create 127.0.0.1 dc # create dc node for himself
  ssh $NODE dc ls nodes --inspect                        # disply dc nodes
  ssh $NODE dc app hello-world config create $REM_NODE hello-world /root/dc/apps/hello-world
  ssh $NODE dc app hello-world up                        # establish hello-world app
  ssh $NODE dc ls apps --inspect                         # display apps
  PORT=$(ssh $NODE dc-yq '.apps.hello-world.compose.services.hello-world.ports.[0].published')
  sleep 1
  netcat -vz $IP $PORT                                   # test access to hello-world
  ssh $NODE dc app hello-world rm                        # stop and remove hello-world app services
  ssh $NODE dc app hello-world config delete             # remove hello-world app definition
  ssh $NODE dc node $REM_NODE config delete              # delete node config definition
fi
if [ "$1" = "" -o "$1" = "delete" ] ; then 
  dc node $NODE vserver delete                           # delete assigned Hetzner cloud server
  dc node $NODE config  delete                           # delete node definition
  rm -f $TEMP
  hcloud server list
  echo "error_detect=$error_detect"
fi
exit $error_detect

