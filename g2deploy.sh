#!/bin/bash
export LANGUAGE=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
echo "export LANGUAGE=en_US.UTF-8" >> /etc/environment
echo "export LANG=en_US.UTF-8" >> /etc/environment
echo "export LC_ALL=en_US.UTF-8" >> /etc/environment
apt-get update
apt-get install -y language-pack-en-base
locale-gen en_US.UTF-8
dpkg-reconfigure locales
apt-get install -y aptitude
aptitude -y full-upgrade
echo "Asia/Kuala_Lumpur" > /etc/timezone
dpkg-reconfigure --frontend noninteractive tzdata
useradd g2 -m -s /bin/bash
printf "Welcome123\nWelcome123\n" | passwd g2
mkdir ~g2/.ssh
chmod 777 /etc/sudoers
cat /etc/sudoers | grep -v g2 > /etc/sudoers.tmp
echo "g2 ALL=(ALL:ALL) ALL" >>/etc/sudoers.tmp
mv /etc/sudoers.tmp /etc/sudoers
chmod 0440 /etc/sudoers
g2deploy_exists=$(grep g2deploy ~/.bashrc)
if [-z "$g2deploy_exists"]
then
cat ~/.bashrc | grep -v g2deploy > ~/.bashrc_tmp
mv ~/.bashrc_tmp ~/.bashrc
else
echo "~/g2deploy/g2deploy.sh" >> ~/.bashrc
shutdown -r now
fi
apt-get install -y htop
