# dc – docker cluster manager

`dc` is a collection of bash scripts to manage **docker compose apps** on a set of **docker hosts (nodes)** from one central **manager**.

It wraps `ssh`, `docker` and `docker compose`: every app has a directory on the manager. From inside that directory you run `dc ...`, and the command runs on whichever node the app is assigned to (via `DOCKER_HOST=ssh://<node>`).

```
dc ls nodes                 # all registered nodes and their state
dc ls apps                  # all registered apps and the nodes they run on
cdapp hello-world           # jump into the app directory
dc up                       # docker compose up -d on the app's node
dc logs -f                  # any other docker compose command
dc login                    # shell inside the app's main service
```

Current version: see [VERSION](./VERSION) or `dc versions`.

**Technically:** plain bash, no daemon and no own runtime. External tools: `ssh`, `docker`/`docker compose`, `yq`, `jq`, `rsync`, `sshfs`. All state is kept in YAML files (definitions under `~/dc`, generated model in `~/.dc/var/dc.yml`). See [Repository layout](#repository-layout-code-map) for where each function is implemented.

---

## Concepts

| Term        | Meaning |
|-------------|---------|
| **manager** | The host where `dc` is installed. It holds all node and app definitions and the ssh key used to reach the nodes. |
| **node**    | A host that `dc` can reach over ssh. It is defined by `~/dc/nodes/<node>/node.yml`. A manager can also be a node of itself. |
| **app**     | A docker compose stack. It is defined by a directory under `~/dc/apps/` that contains `dc-app.yml`, `docker-compose.yml` and `.env`. **App names must be unique across the whole cluster.** |
| **group**   | A free-form label on nodes or apps (`groups:` in `node.yml`, `group:` in `dc-app.yml`). Use it to filter (`dc ls --group=...`, `dc list apps -g ...`, `dc manage sync_group ...`). |
| **vserver** | An optional virtual machine (local/remote KVM or Hetzner Cloud) that is assigned to a node definition and can be created, rebuilt and deleted through `dc`. |

### Node types and states

The `type` in `node.yml` says what `dc` may expect from a node:

| type   | meaning |
|--------|---------|
| `ping` | only pingable |
| `sshd` | reachable via ssh |
| `dock` | ssh + docker installed |
| `dc`   | ssh + docker, member of the dc cluster (can run apps) |
| `dcc`  | like `dc`, and the node has its own dc installation |

`dc node <node> state` returns the state that was actually detected: `ping`, `sshd`, `dock`, `dc`, `dcc`, or `off` (not reachable and `state: standby` in `node.yml`).

Nodes with `connection.type: intermittently` (workstations, backup servers, …) are expected to be offline sometimes.

---

## Requirements

* Ubuntu Server ≥ 22.04 on the manager and the nodes
* openssh-server with public-key login on the nodes (by default `dc` connects as `root`)
* `sudo` rights on the manager (for the installation)

`dc install` adds these on its own: `sshfs`, `jq`, `swaks`, `libnet-ssleay-perl`, plus `yq` and `hcloud` in `/opt/dc/external`.

---

## Installation

```
sudo git clone https://github.com/unimock/dc.git /opt/dc
/opt/dc/bin/dc-install          # 1st run: creates ~/.dc/etc/config from template and stops
vi ~/.dc/etc/config             # adjust if needed
/opt/dc/bin/dc-install          # 2nd run: the actual installation
```

Use `dc-install --force` to install non-interactively with the default config.

The installation does the following:

* creates `~/dc/{apps,nodes,batch,logs,config}` and `/Volumes/{Apps,Data,Cache,Logs,Backup}`
* generates the cluster ssh key `~/dc/nodes/id_ed25519`
* extends `PATH`, `~/.bashrc`, `~/.bash_aliases` (bash completion, `cdapp` alias) and `~/.ssh/config` (`Include ~/.dc/var/ssh/config/*`)
* links `~/dc/config/crontab` to `/etc/cron.d/dc-crontab`
* runs pending migration scripts from `updates/` (each one only once, tracked in `~/.dc/etc/updates.done`)

**Update:** `cd /opt/dc && git pull && dc install`

### Use the manager as a node too

```
cat ~/dc/nodes/id_ed25519.pub >> ~/.ssh/authorized_keys
dc node . config create 127.0.0.1 dc      # "." = local hostname
dc ls nodes
```

---

## Quick start

### 1. Register a node

```
# on the node: allow the cluster key
ssh-copy-id -i ~/dc/nodes/id_ed25519.pub root@<hostname_or_ip>

dc node hugo config create <hostname_or_ip> dc    # type: ping|sshd|dock|dc|dcc
dc node hugo config edit                          # groups, desc, port, ssh_config, …
dc node hugo state                                # should print "dc"
```

### 2. Create an app

```
dc app hello-world config create hugo hello-world ~/dc/apps/hello-world
#                                 ^node ^main_service  ^app directory
cdapp hello-world
dc up
dc ps
```

`config create` copies `templates/create/app/` (a hello-world compose stack) into the app directory. Then edit `docker-compose.yml`, `.env` and `dc-app.yml` to fit your app.

### 3. Remove it again

```
dc app hello-world rm
dc app hello-world config delete
dc node hugo config delete
```

---

## Directory layout

```
/opt/dc/                     # the program (this repository)
~/.dc/etc/config             # main configuration (environment variables MDE_DC_*)
~/.dc/var/dc.yml             # generated cluster model (nodes + apps), see `dc config`
~/.dc/var/ssh/               # generated ssh configs and control sockets per node
~/dc/nodes/<node>/node.yml   # node definitions (+ optional vserver.yml)
~/dc/nodes/id_ed25519        # cluster ssh key
~/dc/apps/**/dc-app.yml      # app definitions (any depth; dot directories are ignored)
~/dc/config/                 # cluster.yml, mail.yml, crontab
~/dc/batch/<name>.list       # batch job definitions
~/dc/logs/                   # batch logs, dc-history.log
```

`~/.dc/var/dc.yml` is rebuilt automatically from `node.yml` and `dc-app.yml` files. To query it, use `dc-yq`:

```
dc-yq '.apps.hello-world.app_dir'
dc-yq '.nodes.hugo.fqdn'
```

### App volumes on the nodes

The `.env` template provides standard volume paths per app (set `ignore_volume_check: true` in `dc-app.yml` for apps that do not follow this scheme):

| variable       | path on node |
|----------------|--------------|
| `DC_VOL_cfg`   | `/Volumes/Apps/<app>/cfg` |
| `DC_VOL_var`   | `/Volumes/Apps/<app>/var` |
| `DC_VOL_data`  | `/Volumes/Data/<app>` |
| `DC_VOL_cache` | `/Volumes/Cache/<app>` |
| `DC_VOL_logs`  | `/Volumes/Logs/<app>` |

---

## dc-app.yml

```yaml
version: "1"
app:
  desc: description of the dc app
  overrule_compose_name:      # if COMPOSE_PROJECT_NAME in .env cannot be used
  ignore_volume_check: false
  main_service: <service>     # target of dc login / cmd / supervisor / ovw
  login_user:                 # optional user for dc login (rootless containers)
  run_level: 5                # start order, lower = earlier (e.g. traefik: 4)
  group:
  control:
    type: compose
    file: docker-compose.yml
  image_list:
    disabled: false           # true = exclude from `dc ls images`
  home:
    - type: default
      state: active           # active | disabled
      node: <node>            # or "." for the local hostname
```

An app can list several `home` entries (nodes). By default `dc` uses the first entry. To pick another one, use `-i <index>` or `-n <node>`; `-ia` runs the command on all of them.

---

## Command reference

`dc` without arguments prints the built-in help. Most sub-commands print their own usage when called without arguments. Bash completion is available (`source <(dc completion)`).

### Global options (app context)

```
-a <app>     work with this app (instead of the current directory)
-c <path>    work with the app in <path> (dc-app.yml or directory)
-n <node>    use this node instead of the one from dc-app.yml
-i <idx>|a   use home entry <idx> (0,1,…) or all (a)
-v           verbose
```

### Cluster overview

```
dc ls nodes  [--skip] [--short] [--group=<g>] [--node=<n>] [--json]
dc ls apps   [--skip] [--short] [--json]
dc ls images [--skip] [--json]      # used images and available updates
dc list nodes all|dc|dcc|used
dc list apps [-n <node>] [-g <group>] [--sort run_level] [--state active|disabled]
dc inspect [-n <node>] runtime|config
dc versions
dc readme                           # print this README
```

By default `dc ls` inspects the nodes live. `--skip` shows only the cached state, and `--json` produces machine-readable output.

#### Status column

`dc ls apps|nodes|images` show a status per row. With `--json` it is in `status` and `status_reason`. A non-zero exit code marks rows that need attention (useful for batch jobs and monitoring).

**`dc ls apps`** (per app and home node)

| | status | status_reason | meaning | exit |
|---|---|---|---|---|
| ✅ | `ok` | `running` | all containers of the app are running | 0 |
| ⏸️ | `paused` | `app_paused` | all containers are paused (`dc pause`) | 0 |
| ❌ | `error` | `container_count` | number of running containers does not match (also after `dc stop`, or partly paused) | 1 |
| ⏰ | `disabled` | `app_disabled` | app disabled in `dc-app.yml` (`home[].state`) | 0 |
| ⏰ | `disabled` | `node_down` | node is in standby (`state: standby` in `node.yml`) | 0 |
| 🔃 | `intermittent` | `intermittent_link` | node with `connection.type: intermittently` is offline | 0 |
| ❓ | `unreachable` | `node_unreachable` | node not reachable or without docker | 1 |
| ☐ | `unchecked` | `not_inspected` | not inspected (`--skip`) | 0 |

**`dc ls nodes`**

| | status | status_reason | meaning | exit |
|---|---|---|---|---|
| ✅ | `ok` | `healthy` | detected state matches `type` in `node.yml` | 0 |
| ⚠️ | `warning` | `disk_high` | disk usage ≥ 92 % | 255 |
| ❌ | `error` | `disk_critical` | disk usage ≥ 98 % | 1 |
| ❌ | `error` | `state_mismatch` | detected state differs from `type` (e.g. docker down) | 1 |
| ⏰ | `standby` | `node_standby` | node not reachable and `state: standby` in `node.yml` | 0 |
| 🔃 | `intermittent` | `intermittent_link` | node with `connection.type: intermittently` is offline | 0 |
| ❓ | `unreachable` | `no_ping` | node not pingable | 1 |
| ☐ | `unchecked` | `not_inspected` | not inspected (`--skip`) | 0 |

**`dc ls images`**

| | status | status_reason | meaning | exit |
|---|---|---|---|---|
| ✅ | `ok` | `current` | version matches the remote image list | 0 |
| ☑ | `outdated` | `newer_available` | remote image list has another version (column "new version") | 254 |
| ⬜ | `unmanaged` | `not_in_image_list` | image is not in the remote image list | 0 |
| ☐ | `unchecked` | `not_inspected` | no remote update check (`--skip`) | 0 |

The remote image list is configured in `~/dc/config/cluster.yml` (`image_list.url`, `image_list.groups`). Apps with `image_list.disabled: true` in `dc-app.yml` are not listed at all.

### Configuration

```
dc config show|refresh|rebuild
dc node <node> config create <hostname_or_ip> [type]
dc node <node> config edit|delete
dc app  <app>  config create <node> <main_service> <app_dir>
dc app  <app>  config edit|delete|yq
```

### Nodes

```
dc node <node> state|ip|ports
dc node <node> cmd <command>        # run a command on the node
dc node <node> list|check [details] # apps on the node
dc node <node> up|rm|rmup|start|stop|pause|unpause|ps|pull    # all apps on the node
dc node <node> nrc [-a <app>]       # number of running containers
dc node <node> update               # apt upgrade of docker-ce
dc node <node> upgrade|upgrade-reboot|reboot
dc node <node> prune
dc node <node> large_files <size> | dir_entries <count>
dc node <node> image [config] [-v]  # list/backup/restore node images
dc node -t <type> <command>         # run for all nodes of a type
dc -n <node> ssh [cmd]              # ssh into a node
dc ssh-control-reset [node ..]      # close stale ssh control masters
```

### Apps (inside the app directory, or with `-a <app>`)

```
dc up|rm|rmup|down|ps|pull|start|stop|pause|unpause
dc logs [-f]
dc <any docker compose command>
dc docker <docker command>          # docker against the app's node
dc login [--root] [command]         # shell / command in main_service
dc cmd <command>                    # without tty (cron)
dc supervisor | dc syslog
dc ovw push|fetch <path>|diff <file>  # overlay files under /service/ovw
dc data pull|push cfg|var|cv [real] # rsync volumes node <-> ./cfg ./var (dry run unless "real")
dc data mount|umount [subdir]       # sshfs mount of the app volume to ./data
dc mounts [umount]                  # list / unmount all sshfs mounts
dc build                            # build image from docker-compose.yml on the target node
dc docker login|push <image>        # push an image from the target node to dockerhub
```

From anywhere, `dc app <app> ...` addresses an app by name:

```
dc app <app> state disabled         # dc rm, then set state: disabled in dc-app.yml
dc app <app> state active           # set state: active in dc-app.yml, then dc up
dc app <app> config <cmd> ...       # app configuration (see Configuration)
dc app <app> <any other command>    # same as: dc -a <app> <command>  (up, stop, logs, login, data, …)
```

### Moving apps between nodes

```
# inside the app directory; <src> and <dst> must both be home nodes in dc-app.yml
dc manage -n <src>:<dst> sync [--images]   # copy cfg/var (+ images) and restart on target
dc manage -n <src>:<dst> copy              # copy data only
dc manage -n <src>:<dst> sync_group <group>
dc manage backup <src> <dst> <mask>        # rotating backups via rdc, e.g. 0,7,14
```

### Batch jobs and reports

```
dc batch nightly create     # creates ~/dc/batch/nightly.list (format described inside)
dc batch nightly run|debug
dc batch nightly delete
```

Reports are sent by mail (configure `~/dc/config/mail.yml`). To schedule the job, enable the example line in `~/dc/config/crontab`.

### Virtual servers

Assign a VM to a node definition and manage its life cycle:

```
dc node <node> vserver assign <vserver>[@kvm-host] <template>
dc node <node> vserver create|install|rebuild|info|delete
dc vserver list
```

Templates live in `templates/create/vserver/` (`hcloud.yml`, `kvm-amd64.yml`, `kvm-arm64*.yml`). A template contains the VM settings and the packages that are installed after creation (`dc-install:` section).

* **Hetzner Cloud** – one-time setup:
  ```
  dc-hcloud context create dc
  dc-hcloud ssh-key create --name dc --public-key-from-file ~/dc/nodes/id_ed25519.pub
  ```
* **KVM** – needs the companion tool `kc` (`/opt/kc`) on the KVM host. `name@host` creates the VM on a remote KVM host.

---

## Examples & tests

* [examples/dc-tests@kvm.md](./examples/dc-tests@kvm.md) – creates a VM, installs dc on it, deploys and tests an app, then deletes everything.
* `testing/` – the same as plain scripts for KVM and Hetzner Cloud.

`dc-md-exec` runs the code blocks of such Markdown files section by section:

```
dc-md-exec examples/dc-tests@kvm.md list
dc-md-exec examples/dc-tests@kvm.md run
dc-md-exec examples/dc-tests@kvm.md run create -o VSERVER="test@kvm1"
```

---

## Repository layout (code map)

```
bin/dc                    # entry point: global options, app context (-a/-c/-n/-i), app and container
                          # commands; delegates cluster commands to bin/dc-<cmd>
bin/dc-app                # dc app <app> ...  (state, config, else passed on to dc -a <app>)
bin/dc-node               # dc node <node> ...  (state, cmd, apps on node, upgrade, image backup/restore)
bin/dc-config             # dc config / node+app config create|edit|delete; builds ~/.dc/var/dc.yml
bin/dc-ls                 # dc ls nodes|apps  (live inspection, --skip, --json)
bin/dc-image              # dc ls images, image update checks
bin/dc-list               # dc list nodes|apps  (plain lists for scripting)
bin/dc-inspect            # dc inspect runtime|config
bin/dc-manage             # dc manage: sync/copy apps between nodes, backups
bin/dc-batch              # dc batch: batch jobs with mail reports
bin/dc-vserver            # dc vserver / dc node <node> vserver: VM life cycle
bin/dc-hcloud, dc-kvm     # backends for Hetzner Cloud and KVM (kvm needs /opt/kc)
bin/dc-install            # installation, update, migrations from updates/
bin/dc-ssh-control-reset  # close stale ssh control masters
bin/dc-yq                 # yq wrapper (defaults to ~/.dc/var/dc.yml)
bin/dc-md-exec            # run code blocks of Markdown files section by section
bin/dc-rdc                # run commands in the rdc backup container on a node (used by dc-manage)
bin/dc-backup             # rotating backup directories by age mask
bin/dc-swarm              # experimental, not finished
bin/dcd                   # copy files listed in ./dcd.list from the app volume to ./dcd.<host>
bin/replace-helper        # dev tool: find/replace strings across a directory tree
funcs/global              # sourced by all scripts: loads ~/.dc/etc/config, refreshes dc.yml, history log
funcs/status_funcs        # status column/emoji for dc ls and dc ls images
funcs/script_funcs        # helpers for timing/error handling in batch scripts
funcs/bash-completion     # bash completion (dc completion)
helper/install/           # scripts run on new nodes/vservers (docker, dist-upgrade, …)
templates/config          # template for ~/.dc/etc/config
templates/create/         # templates for app, node, vserver and cluster config files
updates/<version>.sh      # one-time migrations, run by dc install
examples/, testing/       # end-to-end test scenarios (KVM, Hetzner Cloud)
```

---

## Development notes

* Migrations for existing installations are kept in `updates/<version>.sh` (template: `updates/example.sh`). `dc install` runs each one once.
* Version numbering `x.y.z` is kept in `VERSION`.
* All `dc` / `dc-*` calls are logged to `~/dc/logs/dc-history.log`.
