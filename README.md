# dc  ... docker controller

## Description

dc environment contains a couple of bash scripts to manage generic docker machines (slaves) 
from a central host and directory (master).

It only works as a wrapper for the docker-machine, docker and docker-compose commands for convenient usage.

## Requirements for master and slaves
 * ubuntu-server-16.04
 * openssh-server (pubkey mode)

## Installation (master)
```
git clone https://github.com/unimock/dc.git /opt/dc
/opt/dc/bin/dc-install init    # initialize dc environment
/opt/dc/bin/dc-install docker  # install docker-de (edge)
/opt/dc/bin/dc-install tools   # istall additional tools (pv, tree, compose, machine, ..)
. /etc/profile
```

## Usage
### Slave machines
#### Create a slave machine and install docker-engine on it
```
ABBREV="xyz"
HNAME="host.domain.de"
mkdir ~/.docker/hosts/${ABBREV}
#
# copy or create ssh keys
#
OTHER="zyx"
cp -v ~/.docker/hosts/$OTHER/id_rsa*     ~/.docker/hosts/${ABBREV}/
# ssh-keygen --t rsa -b 4096 ~/.docker/hosts/${ABBREV}/id_rsa
#
# dc-host.yml
#
cat <<EOF > ~/.docker/hosts/${ABBREV}/dc-host.yml
version: "1"
host:
  state: active
  driver: generic
  ip: ${HNAME}
  port: 2376
  ssh:
    port: 22
    user: root
    key: id_rsa
EOF
cat ~/.docker/hosts/${ABBREV}/dc-host.yml
```

#### create a hetzner cloud slave machine

```
ABBREV=
dc-hcloud server register ${ABBREV} # check output for parameters
dc-hcloud server register ${ABBREV} ....
dc-hcloud server create   ${ABBREV}
cat ~/.docker/hosts/${ABBREV}/dc-host.yml
```
#### create a kvm slave (check kc reprot)

### register slave machine in docker-machine

```
dc -h ${ABBREV} create
dc ls
dc -h ${ABBREV} docker info
dc -h ${ABBREV} ssh mkdir /Docker
dc -h ${ABBREV} ssh chmod a+rwx /Docker
```

### join slave machine to swarm with rdc support
```
ABBREV="xyz"
cd ~/Swarm
./swarm.sh join   ${ABBREV}
cd ~/Swarm/rdc
./swarm.control  rm
vi swarm.control
./swarm.control  up
./swarm.control  test
```
### copy data between nodes
```
dc-rdc <source>
rdc . sync /Docker rdc-<target>:/Docker real
```

