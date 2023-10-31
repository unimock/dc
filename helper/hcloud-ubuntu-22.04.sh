#!/bin/bash

echo "$0 : docker installation" 1>&2

apt-get -y update
apt-get -y install ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Add the repository to Apt sources:
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" > /etc/apt/sources.list.d/docker.list
apt-get -y update
apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null 2>&1

echo "$0 : dist-upgrade" 1>&2

DEBIAN_FRONTEND=noninteractive \
  apt-get \
  -o Dpkg::Options::=--force-confold \
  -o Dpkg::Options::=--force-confdef \
  -y --allow-downgrades --allow-remove-essential --allow-change-held-packages \
  dist-upgrade


echo "$0 : set timezone" 1>&2
timedatectl set-timezone Europe/Berlin

echo "$0 : disable PasswordAuthentication in sshd_config" 1>&2
sed -i  's|#PasswordAuthentication.*|PasswordAuthentication no|g' /etc/ssh/sshd_config

echo "$0 : unset root password"
usermod -p ! root

exit 0
