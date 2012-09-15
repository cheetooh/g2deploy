#!/bin/bash
# First argument
# - domain name

# Stackscript ID #1
source stackscript_1.sh

function apache_virtualhost_g2 {
	# Configures a VirtualHost

	# $1 - required - the hostname of the virtualhost to create 

	if [ ! -n "$1" ]; then
		echo "apache_virtualhost() requires the hostname as the first argument"
		return 1;
	fi

	if [ -e "/etc/apache2/sites-available/$1" ]; then
		echo /etc/apache2/sites-available/$1 already exists
		return;
	fi

	mkdir -p /var/www/$1 /var/log/www/$1

	echo "<VirtualHost *:80>" > /etc/apache2/sites-available/$1
	echo "    ServerName $1" >> /etc/apache2/sites-available/$1
	echo "    ServerAlias www.$1" >> /etc/apache2/sites-available/$1
	echo "    ServerAdmin webmaster@$1" >> /etc/apache2/sites-available/$
	echo "    DocumentRoot /var/www/$1/" >> /etc/apache2/sites-available/$1
	echo "    ErrorLog /var/log/www/$1/error.log" >> /etc/apache2/sites-available/$1
    	echo "    CustomLog /var/log/www/$1/access.log combined" >> /etc/apache2/sites-available/$1
        echo "    <Directory /var/www/$1>" >> /etc/apache2/sites-available/$1
        echo "        Options FollowSymLinks MultiViews" >> /etc/apache2/sites-available/$1
        echo "        AllowOverride ALL" >> /etc/apache2/sites-available/$1
        echo "        Order allow,deny" >> /etc/apache2/sites-available/$1
        echo "        allow from all" >> /etc/apache2/sites-available/$1
        echo "    </Directory>" >> /etc/apache2/sites-available/$1
	echo "</VirtualHost>" >> /etc/apache2/sites-available/$1

	a2ensite $1

	touch /tmp/restart-apache2
}

apache_virtualhost_g2 $1
restartServices
