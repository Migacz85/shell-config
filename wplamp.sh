#!/bin/bash

# Script will setup LAMP and install WordPress in the /var/www/html/ folder. 
# Tested on Debian 12

# Run script like that:
# git clone --depth 1 https://github.com/Migacz85/shell-config && chmod +x -R shell-config/ && ./shell-config/wplamp.sh

install_dir="/var/www/html"
#Creating Random WP Database Credenitals
db_name="wp`date +%s`"
db_user=$db_name
db_password=`date |md5sum |cut -c '1-6'`
sleep 1
mysqlrootpass=`date |md5sum |cut -c '1-6'`
sleep 1

#### Install Packages for https and mysql
apt -y update 
apt -y upgrade
apt -y install apache2
apt -y install mariadb-server

#### Start http
rm /var/www/html/index.html
systemctl enable apache2
systemctl start apache2

#### Start mysql and set root password

systemctl enable mysql
systemctl start mysql

echo "I want to create new mysql databse name and user. Hit enter 4 times"
mysql -u root -p -e "CREATE DATABASE $db_name;"
mysql -u root -p -e "CREATE USER '$db_user'@'localhost' IDENTIFIED BY '$db_password';"
mysql -u root -p -e "GRANT ALL PRIVILEGES ON $db_name.* TO '$db_user'@'localhost';"
mysql -u root -p -e "FLUSH PRIVILEGES;" 

####- I.livednstall PHP
apt -y install php php-bz2 php-mysqli php-curl php-gd php-intl php-common php-mbstring php-xml

sed -i '0,/AllowOverride\ None/! {0,/AllowOverride\ None/ s/AllowOverride\ None/AllowOverride\ All/}' /etc/apache2/apache2.conf #Allow htaccess usage

systemctl restart apache2

####Download and extract latest WordPress Package
if test -f /tmp/latest.tar.gz
then
echo "WP is already downloaded."
else
echo "Downloading WordPress"
cd /tmp/ && wget "http://wordpress.org/latest.tar.gz";
fi

/bin/tar -C $install_dir -zxf /tmp/latest.tar.gz --strip-components=1
chown www-data: $install_dir -R

#### Create WP-config and set DB credentials
/bin/mv $install_dir/wp-config-sample.php $install_dir/wp-config.php

/bin/sed -i "s/database_name_here/$db_name/g" $install_dir/wp-config.php
/bin/sed -i "s/username_here/$db_user/g" $install_dir/wp-config.php
/bin/sed -i "s/password_here/$db_password/g" $install_dir/wp-config.php

cat << EOF >> $install_dir/wp-config.php
define('FS_METHOD', 'direct');
EOF

cat << EOF >> $install_dir/.htaccess
# BEGIN WordPress
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteBase /
RewriteRule ^index.php$ – [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
</IfModule>
# END WordPress
EOF

chown www-data: $install_dir -R

##### Set WP Salts
grep -A50 'table_prefix' $install_dir/wp-config.php > /tmp/wp-tmp-config
/bin/sed -i '/**#@/,/$p/d' $install_dir/wp-config.php
/usr/bin/lynx --dump -width 200 https://api.wordpress.org/secret-key/1.1/salt/ >> $install_dir/wp-config.php
/bin/cat /tmp/wp-tmp-config >> $install_dir/wp-config.php && rm /tmp/wp-tmp-config -f
/usr/bin/mysql -u root -e "CREATE DATABASE $db_name"
/usr/bin/mysql -u root -e "CREATE USER '$db_name'@'localhost' IDENTIFIED WITH mysql_native_password BY '$db_password';"
/usr/bin/mysql -u root -e "GRANT ALL PRIVILEGES ON $db_name.* TO '$db_user'@'localhost';"
 
######Display generated passwords to log file.
echo "Database Name: " $db_name >> pass.deleteme
echo "Database User: " $db_user >> pass.deleteme
echo "Database Password: " $db_password >> pass.deleteme
echo "Mysql root password: " $mysqlrootpass >> pass.deleteme

cat pass.deleteme

rm -rf shell-config