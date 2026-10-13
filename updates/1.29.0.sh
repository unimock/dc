#!/bin/bash
#
# update 1.29.0: extend ssh_config of existing node.yml files
#
#   ControlPersist: yes -> 10m  (no endless idle masters)
#   ServerAliveInterval: 5      (dead master on a rebooted node exits
#   ServerAliveCountMax: 3       after ~15s instead of hanging forever)
#
# usage: 1.29.0.sh [-n]    -n ... dry run, only show what would change
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
  expr='.node.ssh_config.ServerAliveInterval = (.node.ssh_config.ServerAliveInterval // 5)
      | .node.ssh_config.ServerAliveCountMax = (.node.ssh_config.ServerAliveCountMax // 3)
      | with(.node.ssh_config; select(.ControlPersist == "yes" or .ControlPersist == null) | .ControlPersist = "10m")'
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

#
# close running control masters - they still run with the old settings
# (endless persist, no keepalive). they are re-established on next use.
#
if [ "$dry_run" = "1" ] ; then
  dc-ssh-control-reset -n
else
  dc-ssh-control-reset
fi

exit 0
