# dc  ... docker controller

## Description

dc environment contains a couple of bash scripts to manage generic docker hosts (slaves) 
from a central host directory (master).

It only works as a wrapper for the docker-machine, docker and docker-compose commands for convenient usage.

## Requirements

 * generic (slave) hosts with sshd (pubkey mode)
 * docker, docker-machine and docker-compose installed on master host

## Installation

```
git clone https://github.com/unimock/dc.git /opt/dc
/opt/dc/bin/dc-install
. /etc/profile

```

## Usage


### Register a slave host and install docker-engine on the slave host

Preparation:
 * Install a generic host (minimal ubuntu-server 16.04) with openssh-server
 * Generate ssh-keys
 * Copy id_rsa.pub to <slave>:/root/.ssh/authorized_keys
 * Test your slave: ssh root@<slave>

```
  dc-init help
  dc-init host slave1 host.domain.com 2376 22 root    # create a host configuration file for slave1 
  dc -h slave1 create                                 # register slave
  dc -h slave1 ssh                                    # test
  dh -h slave1 upgrade                                # install/upgrade docker engine  
```


### Register a service


### dc
rm|up|login

### dc-rdc

### dc-manage


### dc-swarm
ls|rm|up|test

### dc-yml


