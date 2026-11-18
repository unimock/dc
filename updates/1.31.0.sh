#!/bin/bash
#
# update 1.31.0: add "backup: none" to existing dc-app.yml files
#
#   dc backup pauses apps with "backup: pause" for a short final sync. existing
#   apps get the key explicitly with the default "none" (no pause), so that the
#   option is visible in every dc-app.yml. apps that already have a backup key
#   are left unchanged.
#
#   the line is inserted below "run_level:" (same indentation), so comments and
#   formatting stay as they are. without run_level it is appended by yq.
#
# usage: 1.31.0.sh [-n]    -n ... dry run, only show what would change
#

dry_run=""
if [ "$1" = "-n" ] ; then
  dry_run="1"
fi

if [ "$MDE_DC_APP_DIR" = "" -a -f $HOME/.dc/etc/config ] ; then
  . $HOME/.dc/etc/config
fi
if [ ! -d "$MDE_DC_APP_DIR" ] ; then
  echo "$0: MDE_DC_APP_DIR <$MDE_DC_APP_DIR> not found" >&2
  exit 1
fi

ret=0
list=$( find ${MDE_DC_APP_DIR} -name '.?*' -prune -o -name "${MDE_DC_YAML_FILE:-dc-app.yml}" -print )
for yml in $list ; do
  if [ "$( dc-yq '.app | has("backup")' $yml 2>/dev/null )" != "false" ] ; then
    echo "unchanged: $yml"
    continue
  fi
  if [ "$dry_run" = "1" ] ; then
    echo "would update: $yml (backup: none)"
    continue
  fi
  if grep -qE '^[[:space:]]+run_level:' $yml ; then
    # same indentation as run_level, only the first match
    sed -i -E '0,/^([[:space:]]+)run_level:.*$/s//&\n\1backup: none/' $yml
  else
    dc-yq -i '.app.backup = "none"' $yml
  fi
  if [ "$( dc-yq '.app.backup' $yml 2>/dev/null )" = "none" ] ; then
    echo "updated: $yml"
  else
    echo "$0: failed to update $yml" >&2
    ret=1
  fi
done

exit $ret
