> ### Ubuntu Script
>  
> How to run ubuntu-init.sh  
> `curl -sSL https://raw.githubusercontent.com/alelac/public_scripts/main/ubuntu-init.sh | sudo bash`

***

> ### OwnCloud
>  
> Install owncloud in docker compose and dependencies.
> *Tested on Ubuntu Server 24.04*
>
> Variables:
> Installs latest version *(defaults to 10.16.3 if it fails to fetch version)*  
> Puts config files in /opt/docker/owncloud *(will warn if folder is not empty)*  
> Runs http at port 8080  
> Asks for admin account and password  
> Asks for owncloud database password  
> Asks for MySQL (mariadb) root password  
> Configures owncloud to store user files in /mnt/owncloud-data  
> 
> `curl -sSL https://raw.githubusercontent.com/alelac/public_scripts/main/install-owncloud-docker.sh -o deployowncloud.sh && sudo bash deployowncloud.sh; rm deployowncloud.sh`  
