# dc  ... docker cluster manager

## Description

dc environment contains a couple of bash scripts to manage ssh connections and docker compose stacks for different docker nodes (slaves) from a central node (master).

It only works as a wrapper for the docker and docker compose commands for convenient usage.

The management on the master includes ssh definitions for accessing the slaves and the definition of the docker compose stacks.

For example, if you establish a compose stack (app) under dc/apps/hello-word, you can jump into this directory and call docker or docker-compose commands from here, regardless of which node the stack is running on.

```
dc ls apps            # shows all registered apps and the associated nodes apps
cd dc/apps/hello-word
dc compose ...
dc docker ....
dc ...
```

## Naming conventions

### nodes 

### apps

**apps** are multi-container services based on a docker-compose.yml.
App names must always be unique, even if the app services run on different nodes.

### groups 

## Requirements for master and slaves

 * ubuntu-server >= 22.04
 * openssh-server (pubkey mode)

## installation

```
git clone https://github.com/unimock/dc.git /opt/dc
/opt/dc/bin/dc-install     # prepare config file /dc/etc/config
vi ${HOME}/.dc/etc/config  # Check whether the created config file /dc/etc/config fits your needs
/opt/dc/bin/dc-install     # installation
```

If you want to use your dc manager node also as a docker node:
```
cat ${HOME}/dc/nodes/id_ed25519.pub >> ${HOME}/.ssh/authorized_keys # allow dc ssh access
dc node $(hostname) config create 127.0.0.1 dc                      # 'dc config' shows param desc.
dc node $(hostname) edit                                            # add/change properties 
dc ls nodes                                                         # list registered nodes
```

### register a host as **node**

```
node="hugo"
hostname="<hostname_or_ip>"
TYPE="dc"
dc node ${node} config create ${hostname} ${TYPE}   # 'dc config' shows param desc.
dc ls nodes
dc ls nodes --inspect
```


### create a dc app service 

```
TBD
dc ls nodes
dc ls nodes --inspect
```

### TBD dc command overview:

```
dc
dc readme
dc versions
dc install
dc mount
dc umount
dc batch
dc manage
dc ssh-control-reset
dc umount
dc update
dc list nodes
dc list nodes all
dc list nodes dc
dc list nodes used
dc list apps
dc ls nodes
dc ls nodes --inspect
dc ls apps
dc ls apps --inspect
dc config
dc config refresh
dc config rebuild
dc config show
dc node <node> state 
dc node <node> ports
dc node <node> upgrade
dc node <node> update
dc node <node> nrc
dc node <node> nrc -a <app>
dc node <node> reboot
dc node <node> large_files <size>
dc node <node> dir_entries <count>
dc node <node> image
dc node <node> image config [-v]
dc node <node> prune
dc node <node> list
dc node <node> check
dc node <node> check details
dc node <node> start
dc node <node> stop
dc node <node> rm
dc node <node> up
dc node <node> rmup
dc node <node> ps
dc node <node> state
dc node <node> config create <hostname_or_ip> <dc-type>
dc node <node> config delete
dc node <node> vserver assign <vserver> <template>
dc node <node> vserver rebuild
dc node <node> vserver delete
dc app <app> config create <node> <main_service> <app_dir>
dc app <app> config delete
dc app <app> config edit
dc app <app> config yq

```



### TBD: management

```
dc-manage
....
```

### virtual machine support

Create a virtual machine on either local or remote kvm server and register this virtual machine.

#### kvm

1. Create a virtual machine with sshd access.
2. Install dc manager on the virtual machine.
3. Create and start an app on the created dc manager.

[example: dc-tests@kvm.md](./examples/dc-tests@kvm.md)

You can also use the md-code-executer to execute examples directly from md files:

```
dc-md-exec /opt/dc/examples/dc-tests@kvm.md run
dc-md-exec /opt/dc/examples/dc-tests@kvm.md run -o VSERVER="test@kvm1"

```
#### hetzner cloud

requirments:

```
dc-hcloud context create dc  # creates: ~/.config/hcloud/cli.toml
dc-hcloud ssh-key create --name dc --public-key-from-file dc/nodes/id_ed25519.pub
```



# TBD:

### join slave machine to swarm with rdc support
```
ABBREV="xyz"
( cd dc/swarm ; ./swarm.sh join ${ABBREV} )
( cd dc/swarm/rdc ; ./swarm.control rm )
( cd dc/swarm/rdc ; ./swarm.control up )
( cd dc/swarm/rdc ; ./swarm.control test )
```


