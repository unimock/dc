#!/bin/bash
#
# update 1.30.3: silence ssh warnings of existing node.yml files
#
#   LogLevel: ERROR  (with UserKnownHostsFile /dev/null every new connection
#                     printed "Warning: Permanently added ... to the list of
#                     known hosts", messing up the output of dc ls etc.)
#
# usage: 1.30.3.sh [-n]    -n ... dry run, only show what would change
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
  # only add if unset - keep individually chosen values
  expr='with(.node.ssh_config; select(has("LogLevel") | not) | .LogLevel = "ERROR")'
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

# no control master reset needed: LogLevel is a client option, it applies to
# every new ssh call once dc-config has rebuilt the ssh config.

exit 0
