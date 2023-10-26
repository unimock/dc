#!/bin/bash

. /opt/dc/etc/config

FI=/tmp/x
SC=/tmp/y


list=$( find /root/dc/hosts -name "host.yml"  )
#list="/root/dc/hosts/apps0/host.yml"
for FI in $list ; do
  if [ -f ${FI}.backup ] ; then
    echo "error: ${FI}.backup exists!"
    continue
  fi
  cp $FI ${FI}.backup
  group=$( dc-yq  '.host.groups[] | select(. == "dc")' $FI  )
  if [ "$group" = "dc" ] ; then
    dc-yq -i '.host.type = "dc"'   $FI
    dc-yq -i 'del( .host.groups.[] | select(. == "dc"))' $FI
  else
    type=$(dc host -h $h state )
    dc-yq  -i '.host.type = "'$type'"'   $FI
  fi
  dir=`dirname $FI`
  readarray -t a < $dir/host.ssh
  for item in "${a[@]}" ; do
    key=$( echo "$item" | awk '{ print $1}' )
    val=$( echo "$item" | awk '{ print $2}' )
    if [ "$key" = "Host" ] ; then
      continue
    fi
    echo "    <$key> <$val>"
    dc-yq -i  '.host.ssh_config.'$key' = "'$val'"'   $FI
  done
  echo "---------------------------------"
  dc-yq '.' $FI
done
dc config rebuild

replace-helper /root/ 'dc-host'


# nack Aktivierung:
# 1. dc host -h  state  soll dc statt dock ausgeben, wenn type=dc
# 2. dc-list hosts dc # git alle type=dc zurück
# 3. prüfen, was passiert wenn 1. "dc" statt dock zurückgibt"
#     grep "dc-host" bin/*
#




 
exit 0







replace-helper /root   'DC_VOL_service'    'DC_VOL_cfg'
replace-helper /root   'DC_VOL_persistent' 'DC_VOL_var'


# ! ACHTUNG erst MDE_DC_VOL_N_CFG und MDE_DC_VOL_N_VAR in /opt/dc/etc/config setzen

tar cvf /xxx/dc.tar dc
dc config rebuild
cp /opt/dc/var/dc.yml /xxx

clear
list=$(find $MDE_DC_PROJ_DIR -name "docker-compose.yml")
for i in $list ; do
  dir=`dirname $i`
  if [ "$dir" = "/root/dc/projects/mail/server/mail1" -o "$dir" = "/root/dc/projects/mail/server/mail2"  ] ; then
    continue
  fi
  project=$( dc-yq '(( .projects.* | select(.project_dir == "'$dir'" ) | path ) [-1] )' )
  echo "###############################################################"
  echo "# working on $dir  ($project)"
  echo "###############################################################"
  if [ ! -f $dir/.env ] ; then
    echo "  MISSING: $dir/.env (project=$project)"
  else
    found=$(grep "COMPOSE_PROJECT_NAME=" $dir/.env)
    first=$(head -n 1 $dir/.env)
    if [ "$found" != "$first" ] ; then
      echo "  COMPOSE_PROJECT_NAME not in first line for project=$project"
    else
      if [[ $found != *="$project" ]] ; then
         echo "  project != COMPOSE_PROJECT_NAME"
      fi
grep "MDE_DC_VOL" $i
if [ "$?" = "0" ] ; then
echo "--------"
echo sed -i "'"'s|${MDE_DC_VOL_Projects}/'$project'/persistent|${DC_VOL_var}|g'"'" $i
echo sed -i "'"'s|${MDE_DC_VOL_Projects}/'$project'/service|${DC_VOL_cfg}|g'"'"    $i
echo sed -i "'"'s|${MDE_DC_VOL_Cache}/'$project'|${DC_VOL_cache}|g'"'"    $i
echo sed -i "'"'s|${MDE_DC_VOL_Data}/'$project'|${DC_VOL_data}|g'"'"    $i
echo sed -i "'"'s|${MDE_DC_VOL_Logs}/'$project'|${DC_VOL_logs}|g'"'"    $i
fi

    fi 
  fi
done

dc config rebuild
difft /xxx/dc.yml  /opt/dc/var/dc.yml


exit 0



#mkdir /xxx
#tar -czvf /xxx/x.tgz ${MDE_DC_HOST_DIR}/*
#list=$(find ${MDE_DC_HOST_DIR} -name "host.yml")
#for i in $list ; do
#  dc-yq -i 'del(.host.hostname)' $i
#done
#dc config rebuild

replace-helper /root/ "/Docker"


#hosts=$( dc-list hosts dc  )
dc-list hosts dc






vi /opt/dc/etc/config
dc config rebuild

(cd ~/Swarm/rdc ; ./swarm.control rm)

hosts=$( dc-list hosts dc  )

hosts="monitor office"
for h in $hosts ; do 
  dc host -h $h rm
  dc -h $h docker ps
  ssh $h "mv /Volumes/Services /Volumes/Projects"
  dc host -h $h up
  ssh $h "ls /Volumes"
done

dc ls projects --inspect

# restart swarm/rdc
(cd ~/Swarm/rdc ; ./swarm.control up ; ./swarm.control test)

# Abschlusscheck
hosts=$( dc-list hosts dc  )
for h in $hosts ; do
  echo ""
  echo "$h  :"
  echo "   $(ssh $h 'ls /Volumes/Services')"
done

dc ls
dc ls projects --inspect
dc config check

exit 0

