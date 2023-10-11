# dc  ... docker controller

## Description

dc environment contains a couple of bash scripts to manage docker compose projects for different docker hosts (slaves).
from a central host (master).

It only works as a wrapper for the docker and docker compose commands for convenient usage.

The management on the master includes ssh definitions for accessing the slaves and the definition of the docker compose projects.


## Requirements for master and slaves
 * ubuntu-server >= 20.04
 * openssh-server (pubkey mode)

## Installation (master)
```
git clone https://github.com/unimock/dc.git /opt/dc
# TBD:/opt/dc/bin/dc install init    # initialize dc environment
# TBD: /opt/dc/bin/dc install docker  # install docker-ce (stable)
# TBD:/opt/dc/bin/dc install tools   # install additional tools (pv, tree, compose, machine, ..)
# TBD:/opt/dc/bin/dc install hcloud  # optional: manage hetzner cloud hosts
. /etc/profile
```

# TBD:


## Usage

### slave machines

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
  /opt/dc/bin/dc install init    # initialize dc environment
  /opt/dc/bin/dc install docker  # install docker-ce (stable)
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
dc hcloud server register ${ABBREV} # check output for parameters
dc hcloud server register ${ABBREV} ....
dc hcloud server create   ${ABBREV}
cat ~/.docker/hosts/${ABBREV}/dc-host.yml
```
#### create a kvm slave (check kc repo)

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

### install unbound on ubuntu slave
```
ABBREV=
dc -h ${ABBREV} ssh
  host hugo.de.multi.uribl.com # 127.0.0.1              -> not ok
  apt-get install -y unbound
  unbound-anchor
  systemctl disable systemd-resolved
  mkdir -p /etc/NetworkManager/conf.d
  echo -e "[main]\ndns=none\nsystemd-resolved=false" > /etc/NetworkManager/conf.d/nodns.conf
  echo -e "hide-identity: yes\nhide-version: yes"    > /etc/unbound/unbound.conf.d/hide.conf
  init 6
dc -h ${ABBREV} ssh
  dig mailbox.org                          # ;; flags: qr rd ra ad;    ad...-> OK
  host hugo.de.multi.uribl.com             # not found: 3(NXDOMAIN)         -> OK
  dig txt qnamemintest.internet.nl +short  # HORRAY                         -> OK
  netstat -lnp | grep ":53 "               # listen only on 127.0.0.1
  exit 0
```
### copy data between nodes
```
dc-rdc <source>
rdc . sync /Docker rdc-<target>:/Docker real
```

### remove a a service and all related data
```
# TBD: integrate functionality in dc script
cd <serive-directory>
dc -i 0 data umount
dc -i 0 rm
grep image: docker-compose.yml     # print <service-image>
dc -i 0 docker rmi <service-image>
grep "/Docker" docker-compose.yml  # print out <host-volume>
dc -i 0 ssh rm -Rvf <host-volume>
cd ..
rm -Rvf <serive-directory>
```
