#!/bin/bash
# Thanks to https://gist.github.com/Lewiscowles1986/ce14296e3f5222082dbaa088ca1954f7

if [ "$(whoami)" != "root" ]; then
	echo "Run script as ROOT please. (sudo !!)"
	exit
fi


apt-get update -y
apt-get upgrade -y
apt-get dist-upgrade -y

apt-get install -y rpi-update

apt-get install -t stretch -y php7.0 php7.0-fpm php7.0-cli php7.0-opcache php7.0-mbstring php7.0-curl php7.0-xml php7.0-gd php7.0-mysql
apt-get install -t stretch -y nginx acl

update-rc.d nginx defaults
update-rc.d php7.0-fpm defaults

sed -i 's/^;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/' /etc/php/7.0/fpm/php.ini
sed -i 's/# server_names_hash_bucket_size/server_names_hash_bucket_size/' /etc/nginx/nginx.conf

cat > /etc/nginx/sites-enabled/default << "EOF"
# Default server
server {
	listen 80 default_server;
	listen [::]:80 default_server;
	
	server_name _;
	root /var/www/html;
	index index.php index.html index.htm default.html;

	location / {
		try_files $uri $uri/ =404;
	}

	# pass the PHP scripts to FastCGI server
	location ~ \.php$ {
		include snippets/fastcgi-php.conf;
		fastcgi_pass unix:/run/php/php7.0-fpm.sock;
	}

	# optimize static file serving
	location ~* \.(jpg|jpeg|gif|png|css|js|ico|xml)$ {
		access_log off;
		log_not_found off;
		expires 30d;
	}

	# deny access to .htaccess files, should an Apache document root conflict with nginx
	location ~ /\.ht {
		deny all;
	}
}
EOF

mkdir -p /var/www/html
cat > /var/www/html/index.php << "EOF"
<?php

class Application
{
	public function __construct()
	{
		phpinfo();
	}
}

$application = new Application();
EOF

#rm -rf /var/www/html

usermod -a -G www-data pi
chown -R pi:www-data /var/www
chgrp -R www-data /var/www
chmod -R g+rw /var/www

setfacl -d -R -m g::rw /var/www

apt-get -y autoremove

service nginx restart
service php7.0-fpm restart

# MySQL
apt-get -t stretch -y install mariadb-server mariadb-client php-mysqli

read -s -p "Type the password you just entered (MySQL): " mysqlPass

mysql --user="root" --password="$mysqlPass" --database="mysql" --execute="update user set plugin='' where User='root';SET PASSWORD FOR root@localhost=PASSWORD('$mysqlPass'); FLUSH PRIVILEGES;"

sed -i 's/^bind-address/#bind-address/' /etc/mysql/mariadb.conf.d/50-server.cnf
sed -i 's/^skip-networking/#skip-networking/' /etc/mysql/mariadb.conf.d/50-server.cnf

service mysql restart

# PhpMyAdmin
read -p "Do you want to install PhpMyAdmin? <y/N> " prompt
if [ "$prompt" = "y" ]; then
	apt-get install -t stretch -y phpmyadmin
	ln -s /usr/share/phpmyadmin/ /var/www/html
	echo "http://192.168.0.100/phpmyadmin to enter PhpMyAdmin"
fi

apt-get -y autoremove