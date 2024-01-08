# sudo find / -name "create_nginx_config.sh"
# alias add_domain="/path/to/create_nginx_config.sh"
# source ~/.zshrc

#!/bin/bash

create_domain() {
    echo "Creating domain configuration..."
    read -p "Enter folder name: " folder_name
    read -p "Enter index.php path (/public): " path_name
    read -p "Enter PHP version (e.g., 7.4, 8.3): " php_version

    echo "Step 1: Validating inputs..."
    if [ -z "$folder_name" ]; then
        echo "Domain folder name cannot be empty."
        exit 1
    fi

    # Check if .test is already part of the folder name and adjust accordingly
    if [[ $folder_name == *".test"* ]]; then
        domain_name=$folder_name
    else
        domain_name="$folder_name.test"
    fi

    domain_folder="/var/www/html/$folder_name"

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

    echo "Step 2: Checking PHP version and FPM socket..."
    php_fpm_socket="/var/run/php/php${php_version}-fpm.sock"

    if [ ! -S "$php_fpm_socket" ]; then
        echo "PHP version $php_version FPM socket not found."
        exit 1
    fi

    echo "Step 3: Checking and handling existing configuration..."
    nginx_config="/etc/nginx/sites-available/$domain_name"

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

    echo "Step 4: Creating Nginx configuration..."
    nginx_config_content="server {
        listen 127.0.0.1:80;
        server_name $domain_name *.$domain_name;

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

    echo "Step 5: Updating /etc/hosts file..."
    if ! grep -qxF "127.0.0.1 $domain_name www.$domain_name *.$domain_name" /etc/hosts; then
        sudo bash -c "echo '127.0.0.1 $domain_name www.$domain_name *.$domain_name' >> /etc/hosts"
    else
        echo "The entry for $domain_name already exists in /etc/hosts. Skipping."
    fi

    echo "Step 6: Restarting Nginx..."
    sudo service nginx restart
    sudo systemctl restart nginx

    echo "Step 7: Changing folder permissions..."
    sudo chown -R www-data:www-data $domain_folder

    echo "Configuration for $domain_name with PHP version $php_version has been created and enabled."

}

remove_domain() {
    echo "Removing domain configuration..."
    
    read -p "Enter domain folder name to remove: " folder_name

    echo "Step 1: Validating inputs..."
    if [ -z "$folder_name" ]; then
        echo "Domain folder name cannot be empty."
        exit 1
    fi

    domain_name="$folder_name.test"
    domain_folder="/var/www/html/$folder_name"

    echo "Step 2: Removing Nginx configuration..."
    nginx_config="/etc/nginx/sites-available/$domain_name"

    if [ -f "$nginx_config" ]; then
        sudo rm "$nginx_config"
        sudo rm "/etc/nginx/sites-enabled/$domain_name"
        echo "Nginx configuration for $domain_name has been removed."
    else
        echo "Nginx configuration file for $domain_name does not exist. Skipping removal."
    fi

    echo "Step 3: Removing entry from /etc/hosts file..."
    if sudo sed -i "/$domain_name/d" /etc/hosts; then
        echo "Entry for $domain_name in /etc/hosts has been removed."
    else
        echo "Entry for $domain_name not found in /etc/hosts. Skipping removal."
    fi

    echo "Step 4: Restarting Nginx..."
    sudo service nginx restart
    sudo systemctl restart nginx

    echo "Step 5: Changing folder permissions..."
    sudo chown -R www-data:www-data $domain_folder

    echo "Configuration removal for $domain_name has been completed."

}

read -p "Do you want to create or remove a domain? (create/remove): " action

case "$action" in
    create)
        create_domain
        ;;
    remove)
        remove_domain
        ;;
    *)
        echo "Invalid option. Please choose create or remove."
        ;;
esac
