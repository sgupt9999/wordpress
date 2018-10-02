#!/bin/bash
# This script will install a install a LMAP stack and a wordpress instance

###########################################################################
# Start of user inputs
###########################################################################
IPSERVER=18.218.203.127
ROOTPASSWORd="redhat" # For mariadb
FIREWALL="yes" # firewalld should be up and running
#FIREWALL="no"

# Wordpress settings
WPDB="wordpress"
WPUSER="wpuser"
WPPASSWORD="wp123456"
WPTITLE="This is Sanjay's 1st blog"
WPADMIN="wpadmin"
WPADMINPASSWORD="wp123456"
WPADMINEMAIL="wpadmin@yahoo.com"



###########################################################################
# End of user inputs
###########################################################################

if [[ $EUID != 0 ]]
then
	echo
	echo
	echo "ERROR. You need to have root privilges to run this script"
	exit 1
else
	echo
	echo
	echo "This script will install LAMP stack and a Wordpress site as per the user inputs"
	echo
fi


INSTALLPACKAGES1="httpd"
INSTALLPACKAGES2="mariadb mariadb-server mariadb-libs"
INSTALLPACKAGES3="php-mysql libzip php-common php-pdo php php-cli php-gd"
INSTALLPACKAGES4="wget git"

if yum list installed httpd > /dev/null 2>&1
then
        systemctl is-active -q httpd && {
                systemctl stop httpd
                systemctl disable -q httpd
        }
	echo
	echo
        echo "Removing all httpd packages"
        yum remove -y -q $INSTALLPACKAGES1
        userdel -r apache &>/dev/null
        rm -rf /var/www
        rm -rf /etc/httpd
        rm -rf /usr/lib/httpd
        echo "Done"
fi

if yum list installed mariadb-server &>/dev/null
then
        systemctl -q is-active mariadb && {
        systemctl stop mariadb
        systemctl -q disable mariadb
        }
        echo
        echo "#################################"
        echo "Removing old instances of mariadb"
        yum remove $INSTALLPACKAGES2 -y &>/dev/null
        rm -rf /var/lib/mysql
        rm -rf /etc/my.cnf.d
        rm -rf /etc/my.cnf
        echo "Done"
        echo "#################################"
fi

if yum list installed php &>/dev/null
then
        echo
        echo "##################################################"
        echo "Removing old instances of php and related packages"
        yum remove $INSTALLPACKAGES3 -y &>/dev/null
        rm -rf /etc/php.d
        echo "Done"
        echo "##################################################"
fi


echo
echo "#############################################"
echo "Installing support packages $INSTALLPACKAGES4"
yum install -y -q $INSTALLPACKAGES4 &>/dev/null
echo "Done"
echo "#############################################"

echo
echo "#################################"
echo "Installing $INSTALLPACKAGES1"
yum install -y -q $INSTALLPACKAGES1 &>/dev/null
echo "Done"
echo "#################################"

echo
echo
echo "Installing $INSTALLPACKAGES2"
yum install -y -q $INSTALLPACKAGES2 &>/dev/null
echo "Done"

echo
echo
echo "Installing $INSTALLPACKAGES3"
yum install -y -q $INSTALLPACKAGES3 &>/dev/null
echo "Done"


systemctl -q enable --now httpd &>/dev/null
systemctl -q enable --now mariadb &>/dev/null


# Run mysql_secure_installation as separate SQL statements to set up root password
echo
echo "##################################################################################################"
echo "Changing database root password, deleting test database and creating a test user for remote access"
rm -rf ./mysql_secure_installation.sql
cat > ./mysql_secure_installation.sql <<EOF
update mysql.user set password=PASSWORD("$ROOTPASSWORD") where user='root';
DROP USER ''@'localhost';
DROP DATABASE test;
CREATE DATABASE $WPDB;
CREATE USER $WPUSER@localhost IDENTIFIED BY 'WPPASSWORD';
GRANT ALL PRIVILEGES ON $WPDB.* to $WPUSER@localhost IDENTIFIED by '$WPPASSWORD';
FLUSH PRIVILEGES;
EOF

mysql -u root mysql < ./mysql_secure_installation.sql
echo "Done"
echo "##################################################################################################"

###### Installing and configuring Wordpress
rm -rf latest.tar.gz
rm -rf wordpress
wget https://wordpress.org/latest.tar.gz
tar xzvf latest.tar.gz
rsync -avP ./wordpress/ /var/www/html/
mkdir /var/www/html/wp-content/uploads
chown -R apache:apache /var/www/html/*
cd /var/www/html
cp wp-config-sample.php wp-config.php
sed -i "s/database_name_here/$WPDB/" wp-config.php
sed -i "s/username_here/$WPUSER/" wp-config.php
sed -i "s/password_here/$WPPASSWORD/" wp-config.php

####### Wordpress configuration complete


systemctl restart httpd
systemctl restart mariadb

###### Install and configure wordpress commandline

rm -rf wp-cli.phar
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
sudo mv wp-cli.phar /usr/local/bin/wp
/usr/local/bin/wp core install --url="$IPSERVER" --title="$WPTITLE" --admin_user="$WPADMIN" --admin_password="$WPADMINPASSWORD" --admin_email="$WPADMINEMAIL"


if [[ $FIREWALL == "yes" ]]
then
	if systemctl is-active firewalld
	then
		echo
		echo
		echo "Adding http, mysql to firewall"
		firewall-cmd -q --permanent --add-service http 
		firewall-cmd -q --permanent --add-service mysql 
		firewall-cmd -q --reload
		echo "Done"
	else
		echo
		echo "#################################################"
		echo "Firewalld not active. No changes made to firewall"
		echo "#################################################"
	fi
fi


echo
echo "###############################"
echo "Wordpress installation complete"
echo "Done"
echo "###############################"


