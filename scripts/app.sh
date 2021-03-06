#!/bin/bash

# set up the application, sites, and all
#

echo 'This script will create application directories, and overwrite any nginx config files for your sites'
read -p 'Do you want to continue [Y/n]? ' wish
if ! [[ "$wish" == "y" || "$wish" == "Y" ]] ; then
    echo "Aborted"
    exit
fi

# configure environment
#
echo '  --> configuring the environment directories'
if [ ! -d /var/www ] ; then
    mkdir /var/www
fi

# re-source the config file to get the arrays
#
. $basepath/conf/$profile/config

# loop through any available sites and ssl sites
#
for site in "${sites[@]}"
do
    if [ ! -d /var/www/$site ] ; then
        mkdir /var/www/$site
    fi
    if [ ! -d /var/www/$site/www-data ] ; then
        mkdir /var/www/$site/www-data
    fi

    # generate nginx site config files to sites-available and add 
    # symbolic links in sites-enabled
    #
    $basepath/src/nginx_conf/sites-available/example.com.conf.sh $site
    cd /opt/nginx/conf/sites-enabled
    if [ -f /opt/nginx/conf/sites-enabled/$site.conf ] ; then
        rm /opt/nginx/conf/sites-enabled/$site.conf
    fi
    ln -s ../sites-available/$site.conf $site.conf
    cd $basepath
    cp $basepath/src/index.php /var/www/$site/www-data/index.php
    cp $basepath/src/index.html /var/www/$site/www-data/index.html
done

for ssl_site in "${ssl_sites[@]}"
do
    if [ ! -d /var/www/$ssl_site ] ; then
        mkdir /var/www/$ssl_site
    fi
    if [ ! -d /var/www/$ssl_site/www-data ] ; then
        mkdir /var/www/$ssl_site/www-data
    fi

    # generate nginx site config files to sites-available and add 
    # symbolic links in sites-enabled
    #
    $basepath/src/nginx_conf/sites-available/example.com.ssl.conf.sh $site
    cd /opt/nginx/conf/sites-enabled
    if [ -f /opt/nginx/conf/sites-enabled/$site.ssl.conf ] ; then
        rm /opt/nginx/conf/sites-enabled/$site.ssl.conf
    fi
    ln -s ../sites-available/$site.ssl.conf $site.ssl.conf
    cd $basepath
    cp $basepath/src/index.php /var/www/$site/www-data/index.php
    cp $basepath/src/index.html /var/www/$site/www-data/index.html
done

# clone repos
#
echo '  --> install the app files'
if ! [ hash bc 2>/dev/null ]; then
    apt-get install bc
fi

if [ ! -d /home/$username/repos ] ; then
    mkdir /home/$username/repos
fi

# check for any mercurial projects (install if not installed)
#
if [ ${#hg} ]; then
    if ! [ hash hg 2>/dev/null ]; then
        apt-get install mercurial
    fi
    for hg_url in "${hg[@]}"
    do
        reponame=$(basename "$hg_url")
        if ! [ -d /home/$username/repos/$reponame ] ; then
            cd /home/$username/repos
            hg clone $hg_url
        fi
    done
fi

# check for any git projects (install if not installed)
#
if [ ${#git} ]; then
    if ! [ hash git 2>/dev/null ]; then
        apt-get install git
    fi
    for git_url in "${git[@]}"
    do
        reponame=$(basename "$git_url")
        if ! [ -d /home/$username/repos/$reponame ] ; then
            cd /home/$username/repos
            git clone $git_url
        fi
    done
fi

# update permissions
#
chown -R www-data:www-data /var/www
chown -R $username:$username /home/$username/repos

# remove apache
#
ps cax | grep 'apache2' > /dev/null
if [ $? -eq 0 ] ; then
    /etc/init.d/apache2 stop
    /usr/sbin/update-rc.d -f apache2 remove
fi

# restart nginx
#
ps cax | grep 'nginx' > /dev/null
if [ $? -eq 0 ] ; then
    echo '  --> reloading nginx configuration'
    /opt/nginx/sbin/nginx -s reload
fi

echo 'App completed'
echo ''