#!/bin/bash
exit
# 0.9.2
cd /opt/dc
git status
git fetch -a
git checkout rename_project_to_app

cd /root
ll .

mkdir rename_project_to_app
cp -r dc      rename_project_to_app
cp -r utils   rename_project_to_app
cp -r scripts rename_project_to_app

rm -rvf .dc/var

sed -i "s|MDE_DC_VOL_Stacks|MDE_DC_VOL_Apps|g" .dc/etc/config
sed -i "s|MDE_DC_PROJ_DIR|MDE_DC_APP_DIR|g"    .dc/etc/config
sed -i "s|/projects|/apps|g"                   .dc/etc/config
sed -i "s|dc-project.yml|dc-app.yml|g"         .dc/etc/config
cat .dc/etc/config
. .dc/etc/config
######################

list=$(find dc -name dc-project.yml)
for i in $list ; do
  sed -i "s|^project:|app:|g"  $i
  sed -i "s| project | app |g" $i
  mv $i `dirname $i`/dc-app.yml
done 
mv dc/projects dc/apps

replace-helper dc          "MDE_DC_VOL_Stacks" "MDE_DC_VOL_Apps"
replace-helper .dc/etc     "MDE_DC_VOL_Stacks" "MDE_DC_VOL_Apps"
replace-helper dc/batch/   "MDE_DC_VOL_Stacks" "MDE_DC_VOL_Apps"
replace-helper dc/config/  "MDE_DC_VOL_Stacks" "MDE_DC_VOL_Apps"
replace-helper dc/swarm/   "MDE_DC_VOL_Stacks" "MDE_DC_VOL_Apps"
replace-helper utils       "MDE_DC_VOL_Stacks" "MDE_DC_VOL_Apps"
replace-helper scripts     "MDE_DC_VOL_Stacks" "MDE_DC_VOL_Apps"
replace-helper kvm-testing "MDE_DC_VOL_Stacks" "MDE_DC_VOL_Apps"

replace-helper dc          "MDE_DC_PROJ_DIR"   "MDE_DC_APP_DIR"
replace-helper .dc/etc     "MDE_DC_PROJ_DIR"   "MDE_DC_APP_DIR"
replace-helper dc/batch/   "MDE_DC_PROJ_DIR"   "MDE_DC_APP_DIR"
replace-helper dc/config/  "MDE_DC_PROJ_DIR"   "MDE_DC_APP_DIR"
replace-helper dc/swarm/   "MDE_DC_PROJ_DIR"   "MDE_DC_APP_DIR"
replace-helper utils       "MDE_DC_PROJ_DIR"   "MDE_DC_APP_DIR"
replace-helper scripts     "MDE_DC_PROJ_DIR"   "MDE_DC_APP_DIR"
replace-helper kvm-testing "MDE_DC_PROJ_DIR"   "MDE_DC_APP_DIR"

replace-helper dc          "project"   "app"
replace-helper .dc/etc     "project"   "app"
replace-helper dc/batch/   "project"   "app"
replace-helper dc/config/  "project"   "app"
replace-helper dc/swarm/   "project"   "app"
replace-helper utils       "project"   "app"
replace-helper scripts     "project"   "app"
replace-helper kvm-testing "project"   "app"

. .dc/etc/config
. /opt/dc/funcs/bash-completion
dc config rebuild

exit 

#list=$(find dc -name dc-project.yml)
#for i in $list ; do
#  sed -i "s| host: | node: |g"  $i
#done 
#
#list=$(find ./dc/batch ./utils ./scripts -type f)
#for i in $list ; do
#  sed -i "s|hostname|_HOSTNAME_|g"  $i
#  sed -i "s|localhost|_LOCALHOST_|g" $i
#  #echo "##########################################################"
#  #echo "# check $i :"
#  #echo "##########################################################"
#  #grep "host" $i
#  sed -i "s|host|node|g" $i
#  sed -i "s|_HOSTNAME_|hostname|g" $i
#  sed -i "s|_LOCALHOST_|localhost|g" $i
#done


