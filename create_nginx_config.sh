#!/bin/bash

read -p "Enter domain folder name (without .test): " domain_name
read -p "Enter index.php path: " path_name
read -p "Enter PHP version (e.g., 7.4, 8.3): " php_version

if [ -z "$domain_name" ]; then
    echo "Domain folder name cannot be empty."
    exit 1
fi

domain_folder="/var/www/html/$domain_name"

if [ ! -d "$domain_folder" ]; then
    echo "Folder $domain_folder does not exist."
    exit 1
fi

if [ -z "$path_name" ]; then
    path_name="/"
else
    path_name="/$path_name"
fi

if [ -z "$php_version" ]; then
    php_version="8.3"
else
    php_version="$php_version"
fi

php_fpm_socket="/var/run/php/php${php_version}-fpm.sock"

if [ ! -S "$php_fpm_socket" ]; then
    echo "PHP version $php_version FPM socket not found."
    exit 1
fi

nginx_config="/etc/nginx/sites-available/$domain_name.test"

if [ -f "$nginx_config" ]; then
    read -p "Configuration file for $domain_name already exists. Do you want to overwrite it? (yes/no): " overwrite
    case $overwrite in
        [Yy][Ee][Ss]|[Yy])
            echo "Overwriting the existing configuration file."
            ;;
        *)
            echo "Aborting. Configuration was not overwritten."
            exit 0
            ;;
    esac
fi

nginx_config_content="server {
    listen 127.0.0.1:80;
    server_name $domain_name.test www.$domain_name.test *.$domain_name.test;

    root $domain_folder$path_name;
    index index.php;

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:$php_fpm_socket;
    }

    location / {
        try_files \$uri \$uri/ =404;
    }
}"

echo "$nginx_config_content" | sudo tee "$nginx_config" > /dev/null

sudo ln -sf "$nginx_config" "/etc/nginx/sites-enabled/"

# Append domain names to /etc/hosts file
sudo sed -i "/$domain_name\.test/d" /etc/hosts
sudo bash -c "echo '127.0.0.1 $domain_name.test www.$domain_name.test *.$domain_name.test' >> /etc/hosts"

sudo service nginx restart

echo "Configuration for $domain_name.test with PHP version $php_version has been created and enabled."
