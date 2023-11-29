# dc  ... docker cluster manager

## Description

dc environment contains a couple of bash scripts to manage ssh connections and docker compose projects
for different docker hosts (slaves) from a central host (master).

It only works as a wrapper for the docker and docker compose commands for convenient usage.

The management on the master includes ssh definitions for accessing the slaves and the definition of the docker compose projects.


## Requirements for master and slaves

 * ubuntu-server >= 20.04
 * openssh-server (pubkey mode)

## dc manager installation

```bash
git clone https://github.com/unimock/dc.git /opt/dc
/opt/dc/bin/dc-install   # prepare config file /dc/etc/config
# Check whether the created config file /dc/etc/config fits your needs
vi ${HOME}/.dc/etc/config
/opt/dc/bin/dc-install   # installation

# if you want to use your dc manager host also as a docker host:

cat ${HOME}/dc/hosts/id_ed25519.pub >> ${HOME}/.ssh/authorized_keys # allow dc ssh access
dc host $(hostname) config create 127.0.0.1 dc                      # 'dc config' shows param desc.
dc host $(hostname) edit                                            # add/change properties 
dc ls hosts                                                         # list registered hosts

```

### create a dc project service 

```


```

### register a dc slave host 

```
NAME="hugo"
HOSTNAME="<hostname_or_ip>"
TYPE="dc"
dc host ${NAME} config create ${HOSTNAME} ${TYPE}   # 'dc config' shows param desc.
dc ls
```




### Create, install, test and delte a new dc cluster manager on a virtual machine

[example: dc-tests@kvm.md](./examples/dc-tests@kvm.md)

You can also use the md code executer to execute examples directly:

```
dc-md-exec /opt/dc/examples/dc-tests@kvm.md run
dc-md-exec /opt/dc/examples/dc-tests@kvm.md run -o VSERVER="test@kvm1"

```

# TBD:

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


