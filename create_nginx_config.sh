# sudo find / -name "create_nginx_config.sh"
# alias newdomain="/path/to/create_nginx_config.sh"
# source ~/.zshrc
# With your version if php fpm replace fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;

#!/bin/bash

read -p "Enter domain folder name (without .test): " domain_name
read -p "Enter index.php path: " path_name

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

nginx_config="/etc/nginx/sites-available/$domain_name.test"

if [ -f "$nginx_config" ]; then
    echo "Configuration file for $domain_name already exists."
    exit 1
fi

nginx_config_content="server {
    listen 127.0.0.1:80;
    server_name $domain_name.test www.$domain_name.test *.$domain_name.test;
    root $domain_folder$path_name;
    index index.php;
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
    }
    location / {
        try_files \$uri \$uri/ =404;
    }
}"

echo "$nginx_config_content" | sudo tee "$nginx_config" > /dev/null

sudo ln -s "$nginx_config" "/etc/nginx/sites-enabled/"

# Append domain names to /etc/hosts file
sudo sed -i "/$domain_name\.test/d" /etc/hosts
sudo bash -c "echo '127.0.0.1 $domain_name.test www.$domain_name.test *.$domain_name.test' >> /etc/hosts"

sudo service nginx restart

echo "Configuration for $domain_name.test has been created and enabled."
