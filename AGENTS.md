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
* **Ask the user before anything destructive or cluster-wide:** `dc app <app> disable|enable` (stops/starts the app and changes `dc-app.yml`), `dc app <app> delete … real` (always show the dry run without `real` first), `dc app <app> config delete`, `dc node … config delete`, `dc manage …`, `dc vserver …`, `dc data push … real` (overwrites node data with `--delete`), `dc install`, crontab or batch changes.
* **Check exit codes.** App commands (`up`, `rmup`, `rm`, `stop`, `data …`, …) exit non-zero on error. A zero exit code only means that docker compose accepted the command, so always verify the app afterwards with `dc app <app> check --json` (exit 0 = ok).

## Recipe: create a new app

Placeholders: `<app>` (unique name: lowercase letters, digits, `-`, `_`), `<node>` (target node). Follow the steps in this order; each step names the result that must hold before you go on.

**1. Preflight**

```bash
dc ls nodes --json --node=<node>   # must hold: items[0].status == "ok", items[0].type is "dc" or "dcc"
dc ls apps  --json --app=<app>     # must hold: exit code 2 (unknown app = the name is free)
```

**2. Create the definition** (one command, no hand editing for single-container apps)

```bash
dc app <app> new --node=<node> --image=<image:tag> --desc="<one line>" [options] --dry-run   # look at the files
dc app <app> new --node=<node> --image=<image:tag> --desc="<one line>" [options]             # must hold: exit 0
```

Choose the options with these rules (full list: `dc app <app> new --help`):

* Image: always with a fixed tag, never `latest`.
* Web UI behind traefik: `--traefik=<fqdn>:<ctr-port>`, no `--port`. Network and certresolver come from `traefik:` in the node's `node.yml`; if they are wrong there, tell the user instead of editing the labels. Only publish a port (`--port=<host>:<ctr>`) if the service must be reached directly; `check --pre` tells you if it is taken.
* Persistent data: `--vol=cfg:<ctr-path>` for configuration, `--vol=var[/<sub>]:<ctr-path>` for state/databases, `data`/`cache`/`logs` only if needed. Never use other host paths.
* Rootless image: `--login-user=<uid>:<gid>` (becomes the owner of new volume dirs).
* Database or mail inside: `--backup=pause`.
* Settings: `--env=KEY=VALUE` (repeatable), but never for passwords, tokens or keys.
* Secrets: `--secret=KEY` (generates a random password) or `--secret=KEY=VALUE`. The value goes into `.env` (chmod 600), the compose file only gets `${KEY}`. Never print secret values in your messages; say they are in `.env`.

Only for stacks with more services (app + database, …) edit `docker-compose.yml` in `$(dc app <app> dir)` afterwards: add the services, use only `${DC_VOL_*}` for volumes, do not publish database ports, pass secrets as `${KEY}` (e.g. `POSTGRES_PASSWORD=${DB_PASSWORD}`; new secrets go into `.env`, never as plain values into the compose file). Leave the block between `#dc-start` and `#dc-end` in `.env` unchanged.

**3. Check before the start**

```bash
dc app <app> check --pre --json    # must hold: exit 0 ("result": "ok"); fix every item with "status": "error"
```

💡 items (`"status": "hint"`) are fine, e.g. volume dirs that `dc app <app> up` creates.

**4. Seed initial data** (only if the app needs it)

```bash
app_dir=$(dc app <app> dir)
dc app <app> data mount            # creates missing cfg/var (+bind) dirs on the node, sshfs mount to $app_dir/data
cp -a <source>/. "$app_dir/data/cfg/"
cp -a <source>/. "$app_dir/data/var/"
dc app <app> data umount           # always unmount, also after errors
```

Files copied through sshfs belong to root on the node. For rootless images, chown them: `dc app <app> ssh chown -R <uid>:<gid> /Volumes/Apps/<app>/cfg`.

**5. Start and verify**

```bash
dc app <app> up                    # must hold: exit 0
dc app <app> check --json          # must hold: exit 0 ("result": "ok")
```

If `check` fails: `dc app <app> logs -n 50`, fix the files, `dc app <app> rmup`, run `check` again. A container with `health: starting` (💡) needs a little time: run `check` again after 30 s.

**6. Report**: tell the user the app, node, image and URL/port, and include the table output of `dc app <app> check`.

**Roll back** (ask the user first):

```bash
dc app <app> delete --down --volumes          # dry run: show the user what would be deleted
dc app <app> delete --down --volumes real     # only after the user agreed
```

Without `--volumes` only the containers and the app directory are removed and the data on the node stays.

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
