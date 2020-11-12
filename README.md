# dc  ... docker controller

## Description

dc environment contains a couple of bash scripts to manage generic docker machines (slaves) 
from a central host and directory (master).

It only works as a wrapper for the docker-machine, docker and docker-compose commands for convenient usage.

## Requirements for master and slaves
 * ubuntu-server-20.04
 * openssh-server (pubkey mode)

## Installation (master)
```
git clone https://github.com/unimock/dc.git /opt/dc
/opt/dc/bin/dc-install init    # initialize dc environment
#/opt/dc/bin/dc-install docker # install docker-ce (stable)
/opt/dc/bin/dc-install tools   # istall additional tools (pv, tree, compose, machine, ..)
/opt/dc/bin/dc-install hcloud
. /etc/profile
```

## Usage
### Slave machines
#### Installation
```
  #
  # static ip address
  #
    TBD
  #
  # docker installation
  #
  git clone https://github.com/unimock/dc.git /opt/dc
  /opt/dc/bin/dc-install init    # initialize dc environment
  /opt/dc/bin/dc-install docker  # install docker-ce (stable)
  docker run hello-world
  #
  # optional mde installation
  #
  m="mde-server.de"
  wget -O - https://$m/apt/g7-apt-key | apt-key add -
  echo "deb https://$m/apt/ mde main" > /etc/apt/sources.list.d/mde.list
  apt-get update
  apt-get install mde-base
  . /etc/profile
  mde-user -c <abbrev> <pw>
  #
  # config sshd
  #
  vi /root/.ssh/authorized_keys

  vi /etc/ssh/sshd_config
    PermitRootLogin prohibit-password
    PasswordAuthentication no
  
  systemctl reload sshd
  
```

#### Register a slave machine
```
ABBREV=xyz
HNAME=host.domain.de
mkdir -p ~/.docker/hosts/${ABBREV}
#
# copy or create ssh keys
#
OTHER="zyx"
cp -v ~/.docker/hosts/$OTHER/id_rsa*     ~/.docker/hosts/${ABBREV}/
# ssh-keygen -t rsa -b 4096 -f ~/.docker/hosts/${ABBREV}/id_rsa
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
#### create a kvm slave (check kc repro)

### register slave machine in docker-machine

```
dc -h ${ABBREV} create
dc ls
dc -h ${ABBREV} docker info
dc -h ${ABBREV} ssh mkdir -p /Docker/Backup  /Docker/Cache  /Docker/Data  /Docker/Logs  /Docker/Services
dc -h ${ABBREV} ssh chmod -R a+rwx /Docker
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

### install 2G swap file on slave machine
```
ABBREV=
dc -h ${ABBREV} ssh
 dd if=/dev/zero of=/swapfile bs=512M count=4
 chown root:root /swapfile
 chmod 0600 /swapfile
 mkswap /swapfile
 swapon /swapfile
 echo "/swapfile  none swap sw 0 0" >> /etc/fstab
 mount -a
 free -m
```

### copy data between nodes
```
dc-rdc <source>
rdc . sync /Docker rdc-<target>:/Docker real
```

