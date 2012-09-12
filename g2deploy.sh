#!/bin/bash
apt-get update
apt-get install -y language-pack-en-base
export LANGUAGE=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
locale-gen en_US.UTF-8
dpkg-reconfigure locales
apt-get install -y aptitude
aptitude -y full-upgrade
