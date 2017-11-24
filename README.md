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
/opt/dc/bin/dc-install dc      # initialize dc environment
/opt/dc/bin/dc-install docker  # install docker-de (edge)
/opt/dc/bin/dc-install tools   # istall additional tools (pv, tree, compose, machine, ..)
. /etc/profile

```

## Usage


### Create a slave machine and install docker-engine on it

Preparation:
 * Install a generic host (minimal ubuntu-server 16.04) with openssh-server as a slave machine
 * Generate ssh-keys
 * Copy id_rsa.pub to slave-machine:/root/.ssh/authorized_keys
 * Test your slave machine: ssh root@slave-machine

```
  dc-init help
  ABBREV="slave1"
  dc-init host ${ABBREV} host.domain.com 2376 22 root    # create a host configuration file for slave machine 
  dc -h ${ABBREV} create                                 # call docker-machine create for this slave
  dc -h ${ABBREV} ssh                                    # test ssh login for the slave
  dc -h ${ABBREV} upgrade                                # install/upgrade docker engine on the slave
  dc ls                                                  # list slave machines (docker-compose ls)
```


### Register a service


### dc
rm|up|login

### dc-rdc

### dc-manage


### dc-swarm
ls|rm|up|test

### dc-yml


