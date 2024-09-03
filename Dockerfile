FROM php:8.1.0-apache

#php setup, install extensions, setup configs
RUN apt-get update && apt-get install --no-install-recommends -y \
    libpq-dev \
    libzip-dev \
    libxml2-dev \
    mariadb-client \
    zip \
    unzip \
    #install deps for wkhtmltopdf
    libxrender1 \
    libfontconfig1 \
    libxrender1 \ 
    libxext6 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*


RUN pecl install zip pcov
RUN docker-php-ext-enable zip \
    && docker-php-ext-install pgsql \
    && docker-php-ext-install mysqli \
    && docker-php-ext-install pdo_mysql \
    && docker-php-ext-install bcmath \
    && docker-php-ext-install soap \
    && docker-php-source delete

#disable exposing server information
RUN sed -ri -e 's!expose_php = On!expose_php = Off!g' $PHP_INI_DIR/php.ini-production \
    && sed -ri -e 's!ServerTokens OS!ServerTokens Prod!g' /etc/apache2/conf-available/security.conf \
    && sed -ri -e 's!ServerSignature On!ServerSignature Off!g' /etc/apache2/conf-available/security.conf \
    && sed -ri -e 's!KeepAliveTimeout .*!KeepAliveTimeout 65!g' /etc/apache2/apache2.conf \
    && mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

COPY php/xdebug.ini /usr/local/etc/php/conf.d/xdebug.ini.disabled

#apache setup, disable all sites, enable mods, enable configs
COPY apache/disable-elb-healthcheck-log.conf /etc/apache2/conf-available/

RUN a2enmod rewrite setenvif headers \
    && a2enconf disable-elb-healthcheck-log \ 
    && a2dissite * \
    && a2disconf other-vhosts-access-log

#standard sites available
COPY apache/sites/*.conf /etc/apache2/sites-available/

#composer install
COPY --from=composer:2.1.9 /usr/bin/composer /usr/bin/composer

#adds "dev" stage command to enable xdebug
COPY commands/enable-xdebug /usr/local/bin/
RUN chmod +x /usr/local/bin/enable-xdebug \
    && mkdir -p /usr/local/tasks/

#adds common tasks used through Taskfiles
#COPY tasks/ /usr/local/tasks/

#setup task, for running Taskfiles
#RUN curl -o /tmp/taskfile.tar.gz 'https://oberd-static-media.s3.amazonaws.com/builddeps/task/3.34.1/task_linux_386.tar.gz' \
#    && tar -xzf /tmp/taskfile.tar.gz -C /tmp \
#    && mv /tmp/task /usr/local/bin/task \
#    && chmod +x /usr/local/bin/task

CMD ["apache2-foreground"]
