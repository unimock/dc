#!/bin/bash
#
# update 1.29.1: extend ControlPersist of existing node.yml files
#
#   ControlPersist: 10m -> 4h  (10m was too short for a working session,
#                               dead masters are still caught by ServerAlive*)
#
# usage: 1.29.1.sh [-n]    -n ... dry run, only show what would change
#

dry_run=""
if [ "$1" = "-n" ] ; then
  dry_run="1"
fi

if [ "$MDE_DC_HOST_DIR" = "" -a -f $HOME/.dc/etc/config ] ; then
  . $HOME/.dc/etc/config
fi
if [ ! -d "$MDE_DC_HOST_DIR" ] ; then
  echo "$0: MDE_DC_HOST_DIR <$MDE_DC_HOST_DIR> not found" >&2
  exit 1
fi

list=$( find ${MDE_DC_HOST_DIR} -name '.?*' -prune -o -name "node.yml" -print )
for hyaml in $list ; do
  # only nodes reached via ssh carry a ssh_config
  if [ "$( dc-yq '.node | has("ssh_config")' $hyaml )" != "true" ] ; then
    continue
  fi
  # only touch the value set by 1.29.0 - keep individually chosen values
  expr='with(.node.ssh_config; select(.ControlPersist == "10m") | .ControlPersist = "4h")'
  if ! new=$( dc-yq "$expr" $hyaml ) ; then
    echo "$0: failed to process $hyaml" >&2
    exit 1
  fi
  if [ "$new" = "$( dc-yq '.' $hyaml )" ] ; then
    echo "unchanged: $hyaml"
    continue
  fi
  if [ "$dry_run" = "1" ] ; then
    echo "would update: $hyaml"
    diff <( dc-yq '.' $hyaml ) <( echo "$new" )
  else
    dc-yq -i "$expr" $hyaml
    echo "updated: $hyaml"
  fi
done

# no control master reset needed: running masters expire within 10m and
# are re-established with the new value on next use.

exit 0
