FROM ubuntu:16.04
MAINTAINER LiamFiddler <design+docker@liamfiddler.com>
# refer to LiamFiddler <design+docker@liamfiddler.com>
# Set correct environment variables
ENV HOME /root
ENV DEBIAN_FRONTEND noninteractive

# Use Supervisor to run and manage all other services
CMD ["/usr/local/bin/supervisord", "-c", "/etc/supervisord.conf"]

# Install required packages
RUN apt-get update && apt-get install -y \
		curl \
		libcurl3 \
		libcurl3-dev \
		python \
		cron \
		mcrypt \
		nano \
		nginx \
		php7.0-fpm \
		php7.0-cli \
		php7.0-gd \
		php7.0-mcrypt \
		php7.0-sqlite \
		php7.0-curl \
		php7.0-opcache \
		php7.0-mbstring \
		php7.0-zip \
		php7.0-xml \
		php7.0-pgsql\
		php-mysql \
		redis-server \
		nodejs \
		npm && \
	mkdir /share && \
	mkdir -p /etc/supervisord/ && \
	mkdir /var/log/supervisord && \
	mkdir /run/php && \
	curl https://bootstrap.pypa.io/ez_setup.py -o - | python && \
	easy_install supervisor

#msphpsql
RUN apt-get update && apt-get install -y apt-transport-https
RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
RUN curl https://packages.microsoft.com/config/ubuntu/16.04/prod.list > /etc/apt/sources.list.d/mssql-release.list
RUN exit
RUN apt-get update
RUN ACCEPT_EULA=Y apt-get install -y msodbcsql mssql-tools 
RUN apt-get install unixodbc-dev
RUN echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bash_profile
RUN echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bashrc
RUN source ~/.bashrc

RUN pear config-set php_ini `php --ini | grep "Loaded Configuration" | sed -e "s|.*:\s*||"` system
RUN pecl install sqlsrv
RUN pecl install pdo_sqlsrv

RUN echo "extension=sqlsrv.so" >> /etc/php/7.0/php/php.ini
RUN echo "extension=pdo_sqlsrv.so" >> /etc/php/7.0/php/php.ini

# Intall composer
RUN curl -sS https://getcomposer.org/installer | php
RUN mv composer.phar /usr/local/bin/composer
RUN composer config -g repo.packagist composer https://packagist.phpcomposer.com


# Copy supervisor config files, Laravel cron file, & default site configuration
COPY provision/conf/supervisor.conf /etc/supervisord.conf
COPY provision/service/* /etc/supervisord/
COPY provision/cron/laravel /etc/cron.d/laravel
COPY provision/conf/nginx-default /etc/nginx/sites-available/default

# Configure PHP, Nginx, Redis, and clean up
RUN sed -i 's/;opcache.enable=0/opcache.enable=1/g' /etc/php/7.0/fpm/php.ini && \
	sed -i 's/;opcache.fast_shutdown=0/opcache.fast_shutdown=1/g' /etc/php/7.0/fpm/php.ini && \
	sed -i 's/;opcache.enable_file_override=0/opcache.enable_file_override=1/g' /etc/php/7.0/fpm/php.ini && \
	sed -i 's/;opcache.revalidate_path=0/opcache.revalidate_path=1/g' /etc/php/7.0/fpm/php.ini && \
	sed -i 's/;opcache.save_comments=1/opcache.save_comments=1/g' /etc/php/7.0/fpm/php.ini && \
	sed -i 's/;opcache.revalidate_freq=2/opcache.revalidate_freq=60/g' /etc/php/7.0/fpm/php.ini && \
	sed -i 's/pm.max_children = 5/pm.max_children = 12/g' /etc/php/7.0/fpm/pool.d/www.conf && \
	sed -i 's/pm.start_servers = 2/pm.start_servers = 4/g' /etc/php/7.0/fpm/pool.d/www.conf && \
	sed -i 's/pm.min_spare_servers = 1/pm.min_spare_servers = 4/g' /etc/php/7.0/fpm/pool.d/www.conf && \
	sed -i 's/pm.max_spare_servers = 3/pm.max_spare_servers = 8/g' /etc/php/7.0/fpm/pool.d/www.conf && \
	echo "daemon off;" >> /etc/nginx/nginx.conf && \
	sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" /etc/php/7.0/fpm/php-fpm.conf && \
	sed -i 's/^daemonize yes/daemonize no/' /etc/redis/redis.conf && \
	sed -i 's/^# maxmemory <bytes>/maxmemory 32mb/' /etc/redis/redis.conf && \
	sed -i 's/^# maxmemory-policy volatile-lru/maxmemory-policy allkeys-lru/' /etc/redis/redis.conf && \
	chmod 644 /etc/cron.d/laravel && \
	ln -s /usr/bin/nodejs /usr/bin/node && \
	locale-gen en_US.UTF-8 && \
	apt-get -yq autoremove --purge && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Set the language
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Expose volumes and ports
#VOLUME ["/share"]
EXPOSE 80
