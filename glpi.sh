#!/bin/bash
## For DEBIAN 10
## MySQL is not in official repo of Debian 10 (2020-04-19)
## Only MariaDB is available by default
## DON'T FORGET TO CHANGE PASSWORD

if [[ $(id -u) != 0 ]]; then 
		echo -e "${R}Please use the script as root${N}"
		exit 1 
fi

# Installation of webserver, minimal for GLPI to be functional https://glpi-install.readthedocs.io/en/latest/prerequisites.html
apt update
apt install apache2 mariadb-server php7.3 php7.3-curl php7.3-gd php7.3-json php7.3-mbstring php7.3-mysql php7.3-xml -y

# Create user and database glpi, CHANGE PASWWORD FOR GLPI USER
mysql -u root -e "CREATE USER IF NOT EXISTS 'glpi'@'localhost' IDENTIFIED BY 'glpi';"
mysql -u root -e "CREATE DATABASE IF NOT EXISTS glpi;"
mysql -u root -e "GRANT ALL PRIVILEGES ON glpi.* TO 'glpi'@'localhost';"
mysql -u root -e "FLUSH PRIVILEGES;"

# 2020-04-19 GLPI 9.4.5
# Copy GLPI files on webserver
wget https://github.com/glpi-project/glpi/releases/download/9.4.5/glpi-9.4.5.tgz -P /tmp/
tar xvf /tmp/glpi-9.4.5.tgz -C /var/www/html/

# Create directories with permission https://github.com/glpi-project/glpi/releases/latest

mkdir /var/log/glpi
cp -R /var/www/html/glpi/files /var/lib/glpi
cp -R /var/www/html/glpi/config /etc/glpi

#Create configuration files
printf "<?php\
\ndefine('GLPI_CONFIG_DIR', '/etc/glpi/');\
\n
\nif (file_exists(GLPI_CONFIG_DIR . '/local_define.php')) {\
\n   require_once GLPI_CONFIG_DIR . '/local_define.php';\
\n}"\
> /var/www/html/glpi/inc/downstream.php

printf "<?php\
\ndefine('GLPI_VAR_DIR', '/var/lib/glpi');\
\ndefine('GLPI_LOG_DIR', '/var/log/glpi');"\
> /etc/glpi/local_define.php

chown -R www-data:www-data /var/www/html/glpi /etc/glpi /var/log/glpi /var/lib/glpi 

# Install GLPI
php /var/www/html/glpi/bin/console db:install --no-interaction --db-host localhost --db-name glpi --db-user glpi --db-password glpi
rm /var/www/html/glpi/install/install.php

# Secure /etc/glpi/
chmod -R 550 /etc/glpi/
# Secure "install" folder https://glpi-install.readthedocs.io/en/latest/install/index.html#post-installation
printf "<IfModule mod_authz_core.c>\
\n    Require local\
\n</IfModule>\
\n<IfModule !mod_authz_core.c>\
\n    order deny, allow\
\n    deny from all\
\n    allow from 127.0.0.1\
\n    allow from ::1\
\n</IfModule>\
\nErrorDocument 403 "'"<p><b>Restricted area.</b><br />Only local access allowed.<br />Check your configuration or contact your administrator.</p>"'""\
> /var/www/html/glpi/install/.htaccess

# To fix newly created files
chown -R www-data:www-data /var/www/html/glpi /etc/glpi /var/log/glpi /var/lib/glpi 