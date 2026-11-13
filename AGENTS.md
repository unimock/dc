# AGENTS.md – working with dc as an AI agent

`dc` is a bash-based docker compose cluster manager. The full documentation is in [README.md](README.md) (`dc readme` prints it). This file covers what an agent needs on top of it: how to run things non-interactively and how to check results.

## Ground rules

* **Non-interactive only.** `cdapp` is a shell alias and does not exist in non-interactive shells (use `dc app <app> dir` instead). Do not use `vi`, `dc login`, or `dc config edit`. Instead:
  * run app commands as `dc app <app> <cmd>` (same as `dc -a <app> <cmd>`), which works from any directory
  * get the app directory with `dc app <app> dir` (exit 1 if the app is unknown), e.g. `cd "$(dc app <app> dir)"`
  * edit `docker-compose.yml`, `.env` and `dc-app.yml` with your file tools
* **Read state as JSON, not from tables.** `dc ls nodes|apps|images --json` prints a stable envelope (`kind`, `count`, `items[]`) with `status` / `status_reason` per row, and the exit code follows the status. See README: *JSON output (`--json`)* and *Status column*. `dc ls apps --json` also has `image` (main service) and `images[]` (`service`, `image`, `tag`), and filters with `--app=<app>`, `--group=<group>` and `--node=<node>` (home node); unknown options fail with exit code 1. For anything not in the JSON, query the generated model with `dc-yq '<yq expr>'` (for example `dc-yq '.nodes.<node>.fqdn'`).
* **Never edit `~/.dc/var/dc.yml`.** It is generated from `~/dc/nodes/*/node.yml` and `~/dc/apps/**/dc-app.yml`, and rebuilt automatically when those files change.
* **App names are unique across the whole cluster.** Leave other apps alone.
* **Ask the user before anything destructive or cluster-wide:** `dc app <app> disable|enable` (stops/starts the app and changes `dc-app.yml`), `dc app <app> config delete`, `dc node … config delete`, `dc manage …`, `dc vserver …`, `dc data push … real` (overwrites node data with `--delete`), `dc install`, crontab or batch changes.
* **Check exit codes.** App commands (`up`, `rmup`, `rm`, `stop`, `data …`, …) exit non-zero on error. A zero exit code only means that docker compose accepted the command, so still verify the result with `dc ls apps --json --app=<app>` (see step 6).

## Recipe: create a new app

Placeholders: `<app>` (unique name), `<node>` (target node), `<svc>` (main compose service).

**1. Preflight**

```bash
dc ls nodes --json --node=<node>   # items[0].status == "ok" and items[0].type is "dc" or "dcc"
dc ls apps  --json --app=<app>     # exit code 2 = unknown app = the name is free
```

**2. Create the definition**

```bash
dc app <app> config create <node> <svc> ~/dc/apps/<app>
```

This copies `templates/create/app/` into the app directory and replaces `<app_name>`, `<main_service>`, `<node>` and `<image>`. The target directory must not exist yet.

**3. Adapt the files** (in `$(dc app <app> dir)`)

* `docker-compose.yml`: set the real `image:`. The template publishes the fixed port `54321:8000`: change it or remove it, because ports must be free on the node (check with `dc app <app> ssh ss -ltn`).
* Volumes: use only the `${DC_VOL_*}` variables from `.env`. `cfg` and `var` are required; `data`, `cache` and `logs` are optional. See README: *App volumes on the nodes*.
* `dc-app.yml`: `desc`, `main_service`, and optionally `login_user` (numeric `uid:gid` for rootless images; it becomes the owner of new volume dirs), `run_level`, `group`.
* Leave the block between `#dc-start` and `#dc-end` in `.env` unchanged.

**4. Check**

```bash
(cd "$(dc app <app> dir)" && docker compose config -q)   # compose syntax / variable expansion
dc config check                                    # look at the lines starting with [<app>]; ❌ = must fix
```

`dc config check` covers the whole cluster, so ❌ lines of other apps are not your concern.

**5. Seed initial data** (only if the app needs it)

```bash
app_dir=$(dc app <app> dir)
dc app <app> data mount            # creates missing cfg/var (+bind) dirs on the node, sshfs mount to $app_dir/data
cp -a <source>/. "$app_dir/data/cfg/"
cp -a <source>/. "$app_dir/data/var/"
dc app <app> data umount           # always unmount, also after errors
```

Files copied through sshfs belong to root on the node. For rootless images, chown them: `dc app <app> ssh chown -R <uid>:<gid> /Volumes/Apps/<app>/cfg`.

`data mount` / `data umount` are idempotent (an existing or missing mount gives 💡 and exit code 0). `mount` fails if `<app_dir>/data` is a non-empty local directory; move it away first.

**6. Start and verify**

```bash
dc app <app> up
dc ls apps --json --app=<app>      # every items[0].home[].status must be "ok" (exit code 0)
dc app <app> logs -n 50            # if not ok
```

**Roll back** (ask the user first): `dc app <app> rm`, then `dc app <app> config delete`. This removes the app directory. Volume data on the node below `/Volumes/*/<app>` stays.

## Recipe: disable / enable an app

Ask the user first. `dc app <app> down` only stops the app; `dc ls apps` then reports an error because the app is still `active`. To switch it off permanently, use:

```bash
dc app <app> disable               # dc down, then home[].state active -> disabled; dc-app.yml stays unchanged if down fails
dc ls apps --json --app=<app>      # items[0].home[].status == "disabled", status_reason == "app_disabled"

dc app <app> enable                # home[].state disabled -> active, then dc up; exit code of up
dc ls apps --json --app=<app>      # every items[0].home[].status must be "ok"
```

`standby` entries in `home[]` are left unchanged.

## Developing /opt/dc itself

* Plain bash. Code map: README *Repository layout (code map)*. Run `bash -n <file>` after edits.
* Update the README together with every behaviour change; it is the user documentation.
* Bump `VERSION` for every functional change. "minor" means the last digit (x.y.Z).
* One-time migrations for existing installations go into `updates/<version>.sh`. They are run once by `dc install`.
* Keep the `--json` output backward compatible: add fields, do not rename or remove them.
