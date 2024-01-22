# test @ kvm

## Create, install, test and delte a new dc cluster manager on a virtual machine



[//]: # (md-exec: global commands)
```global
. /opt/dc/funcs/script_funcs
sf_start
error_detect=0
err_report() { printf "!\n! Error on line $1\n!\n" ; error_detect=1 ; } ; trap 'err_report $LINENO' ERR

HOST="test"              # local dc node name
VSERVER="test@tkvm1"     # create remote kvm machine @kvm1 server
#VSERVER="test"           # create local kvm machine
SLAVE="dc-slave"         # remote dc node name
TEMPL="kvm"              # vserver template which includes kvm-/cloud-config-/dc-install settings 
```

[//]: # (md-exec: create test env)
```create
dc node $HOST config create test.intra dock  # create new node definition with hostname test.intra and type="dock"
dc node $HOST vserver assign $VSERVER $TEMPL # assign virtual server to the new node
dc node $HOST vserver create                 # create assigned machine
dc node $HOST state                          # check if new node returns dc
# install dc
ssh $HOST git clone https://github.com/unimock/dc.git /opt/dc
ssh $HOST /opt/dc/bin/dc-install --force     # --force .. do not change default settings
ssh $HOST 'cat /root/dc/nodes/id_ed25519.pub >> /root/.ssh/authorized_keys'
```

[//]: # (md-exec: execute tests)
```test
IP=$(dc node $HOST ip)
echo "IP=$IP"
# lets play around on the new dc cluster manager
ssh $HOST dc node $SLAVE config create $IP dc
state=$(ssh $HOST dc node $SLAVE state)
if [ "$state" != "dc" ] ; then
  sf_set_error
fi
ssh $HOST dc app hello-world config create $SLAVE hello-world /root/dc/apps/hello-world
ssh $HOST dc -a hello-world up
#ssh $HOST dc ls apps --inspect
PORT=$(ssh $HOST dc-yq '.apps.hello-world.compose.services.hello-world.ports.[0].published')
sleep 1
netcat -vz $IP $PORT
if [ "$?" != "0" ] ; then
  sf_set_error
fi
ssh $HOST dc -a hello-world rm                 # stop and remove hello-world app services
ssh $HOST dc app hello-world config delete # remove hello-world app definition
ssh $HOST dc node $SLAVE config delete         # delete node config definition
```

Delete 

[//]: # (md-exec: delete test env)
```delete
dc node $HOST vserver delete                   # delete assigned kvm machine
dc node $HOST config  delete                   # delete node definition
echo "error_detect=$error_detect"
```

[//]: # (md-exec: global commands)
```global
if [ "$error_detect" != "0" ] ; then
  sf_set_error
fi
sf_end
```
