# dc  ... docker cluster manager

## Description

dc environment contains a couple of bash scripts to manage ssh connections and docker compose stacks for different docker hosts (slaves) from a central host (master).

It only works as a wrapper for the docker and docker compose commands for convenient usage.

The management on the master includes ssh definitions for accessing the slaves and the definition of the docker compose stacks.

For example, if you establish a compose stack (project) under dc/projects/hello-word, you can jump into this directory and call docker or docker-compose commands from here, regardless of which host the stack is running on.

```
dc ls projects            # shows all registered projects and the associated hosts projects
cd dc/projects/hello-word
dc compose ...
dc docker ....
dc ...
```

## Naming conventions

### hosts 

### projects

projects are docker-compose stacks. Project names must always be unique, even if the project services run on different hosts. 

### groups 

## Requirements for master and slaves

 * ubuntu-server >= 20.04
 * openssh-server (pubkey mode)

## installation

```
git clone https://github.com/unimock/dc.git /opt/dc
/opt/dc/bin/dc-install   # prepare config file /dc/etc/config
# Check whether the created config file /dc/etc/config fits your needs
vi ${HOME}/.dc/etc/config
/opt/dc/bin/dc-install   # installation
```

If you want to use your dc manager host also as a docker host:
```
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


### virtual machine support

Create a virtual machine on either local or remote kvm server and register this virtual machine.

#### kvm

1. Create a virtual machine with sshd access.
2. Install dc manager on the virtual machine.
3. Create and start a project on the created dc manager.

[example: dc-tests@kvm.md](./examples/dc-tests@kvm.md)

You can also use the md code executer to execute examples directly:

```
dc-md-exec /opt/dc/examples/dc-tests@kvm.md run
dc-md-exec /opt/dc/examples/dc-tests@kvm.md run -o VSERVER="test@kvm1"

```
#### hetzner cloud

requirments:

```
dc-hcloud context create dc  # creates: ~/.config/hcloud/cli.toml
dc-hcloud ssh-key create --name dc --public-key-from-file dc/hosts/id_ed25519.pub
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


