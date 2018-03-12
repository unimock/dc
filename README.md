# dc  ... docker controller - manage generic docker machines from a central host and directory 

## Description

dc environment contains a couple of bash scripts to manage generic docker machines (slaves) 
from a central host and directory (master).

It only works as a wrapper for the docker-machine, docker and docker-compose commands for convenient usage.

## Requirements

 * generic (slave) hosts with sshd (pubkey mode)
 * docker, docker-machine and docker-compose installed on master host

## Installation

```
git clone https://github.com/unimock/dc.git /opt/dc
/opt/dc/bin/dc-install init    # initialize dc environment
/opt/dc/bin/dc-install docker  # install docker-de (edge)
/opt/dc/bin/dc-install tools   # istall additional tools (pv, tree, compose, machine, ..)
. /etc/profile

```

## Usage


### Create a slave machine and install docker-engine on it

```
cd ~
ABBREV="xyz"
HNAME="host.domain.de"
#
# copy or create ssh keys
#
OTHER="zyx"
mkdir .docker/hosts/${ABBREV}
cp -v .docker/hosts/$OTHER/id_rsa*     .docker/hosts/${ABBREV}/
#
# dc-host.yml
#
cat <<EOF > .docker/hosts/${ABBREV}/dc-host.yml
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
cat .docker/hosts/${ABBREV}/dc-host.yml
#
# create and test
#
dc -h ${ABBREV} create
dc ls
dc -h ${ABBREV} docker info
dc -h ${ABBREV} ssh mkdir /Docker
dc -h ${ABBREV} ssh chmod a+rwx /Docker
```

### create swarm node with rdc support
```
ABBREV="xyz"
cd ~/Swarm
/swarm.sh join   ${ABBREV}
cd ~/Swarm/rdc
./swarm.control  rm
vi swarm.control
./swarm.control  rm
./swarm.control  test
```

### copy data between nodes
```
dc-rdc <source>
rdc . sync /Docker rdc-<target>:/Docker real

```

