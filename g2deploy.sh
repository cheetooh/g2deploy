#!/bin/bash
# First argument
# - norestart

function goodstuff_g2 {
    # Installs the REAL vim, wget, less, and enables color root prompt and the "ll" list long alias
    aptitude -y install wget vim less
    sed -i'.bk' -e 's/^#PS1=/PS1=/' /home/g2/.bashrc # enable the colorful root bash prompt
    sed -i'.bk' -e "s/^#alias ll='ls -l'/alias ll='ls -al'/" /home/g2/.bashrc # enable ll list long alias <3
}

# Stackscript ID #1
source stackscript_1.sh
# Stackscript ID #123
source stackscript_123.sh

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
echo "Asia/Kuala_Lumpur" > /etc/timezone
dpkg-reconfigure --frontend noninteractive tzdata
useradd g2 -m -s /bin/bash
printf "Welcome123Juzit\nWelcome123Juzit\n" | passwd g2
mkdir ~g2/.ssh
chmod 777 /etc/sudoers
count=$(grep -i "g2" /etc/sudoers|wc -l)
if test $count -eq 0
then
sed -i'.bk' -e '/# User privilege specification/ a\g2 ALL=(ALL:ALL) ALL' /etc/sudoers
fi
count=$(grep -i "pwfeedback" /etc/sudoers|wc -l)
if test $count -eq 0
then
sed -i'.bk' -e "s/env_reset/env_reset,pwfeedback/" /etc/sudoers
fi
chmod 0440 /etc/sudoers
if [ $1 != "norestart" ]; then
count=$(grep -i "g2deploy" ~/.bashrc|wc -l)
if test $count -gt 0
then
cat ~/.bashrc | grep -v g2deploy > ~/.bashrc_tmp
mv ~/.bashrc_tmp ~/.bashrc
else
echo "~/g2deploy/g2deploy.sh" >> ~/.bashrc
shutdown -r now
fi
fi
system_update
postfix_install_loopback_only
mysql_install "Welcome123Juzit" && mysql_tune 40

###########################################################
# PHP
###########################################################
php_install_with_apache && php_tune
sed -i'.bk' 's/^expose_php.*/expose_php = Off/' /etc/php5/apache2/php.ini

###########################################################
# Apache
###########################################################
apache_install && apache_tune 40
echo "ServerSignature Off" >> /etc/apache2/apache2.conf
echo "ServerTokens Prod" >> /etc/apache2/apache2.conf

###########################################################
# SSH
###########################################################
system_sshd_permitrootlogin no
system_sshd_passwordauthentication no
system_user_add_ssh_key "g2" "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCmG4HXpZLao+iS8oNH5o+6p35OzyJEJ/GRkyHqUVr1oVapCs0eTXYPL0vCqbXYCpZBM3Hz4XzM4sCBgZiY7ymCC2Y1JVdwEZ/DrcB6YYS4HmzLGmC5gH11/MOfqEBmWaKl/sy4ARJYXggX5yTraFM3w+JWEza2jB0qMIv8EvBxdVR1ItyUK5Mwg8sn4y8YpT+nnXOvLRL89dnkiqo6UR0AhpPWIOrnN9vm0ZnNMy2RVIYGv1vo+fS1KeXxtpLlaBPpKZBBKbveqaqH/ceyPtHaP+sCg94FzUydXv2ZOEnnLCZtxxf49cY9pa6R3Uv9v3Wjvdj8L7YL/CnIqQaPIizn g2@G2MAC.local"
chown g2:g2 ~g2/.ssh/authorized_keys

apt-get install -y fail2ban
apt-get install -y htop
apt-get install -y php5-suhosin
apt-get install -y phpmyadmin

goodstuff
goodstuff_g2

mysql_secure_installation
passwd g2

system_security_ufw_configure_basic
ufw allow 1194
system_lock_user

shutdown -r now
