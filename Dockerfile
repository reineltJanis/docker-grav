FROM php:8.1-apache

# Enable Apache Rewrite + Expires Module
RUN a2enmod rewrite expires && \
    sed -i 's/ServerTokens OS/ServerTokens ProductOnly/g' \
    /etc/apache2/conf-available/security.conf

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    unzip \
    libfreetype6-dev \
    libjpeg-dev \
    libpng-dev \
    libwebp-dev \
    libxpm-dev \
    libyaml-dev \
    libzip4 \
    libzip-dev \
    zlib1g-dev \
    libicu-dev \
    libldap2-dev \
    g++ \
    git \
    cron \
    vim \
    && docker-php-ext-install opcache \
    && docker-php-ext-configure intl \
    && docker-php-ext-install intl \
    && docker-php-ext-configure gd --enable-gd --with-jpeg --with-freetype --with-webp --with-xpm \
    && docker-php-ext-install -j$(nproc) gd \
    && docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu/ \
    && docker-php-ext-install ldap \
    && docker-php-ext-install zip \
    && docker-php-ext-install exif \
    && rm -rf /var/lib/apt/lists/*

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
    echo 'opcache.memory_consumption=256'; \
    echo 'opcache.interned_strings_buffer=16'; \
    echo 'opcache.max_accelerated_files=8000'; \
    echo 'opcache.revalidate_freq=2'; \
    echo 'opcache.fast_shutdown=1'; \
    echo 'opcache.enable_cli=1'; \
    echo 'upload_max_filesize=128M'; \
    echo 'post_max_size=128M'; \
    echo 'expose_php=off'; \
    } > /usr/local/etc/php/conf.d/php-recommended.ini

RUN pecl install apcu \
    && pecl install yaml-stable \
    && pecl install redis \
    && docker-php-ext-enable apcu yaml redis

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Set user to www-data
RUN chown www-data:www-data /var/www
USER www-data

# Define Grav specific version of Grav or use latest stable
ARG GRAV_VERSION=latest

# Install grav
WORKDIR /var/www
RUN curl -o grav-admin.zip -SL https://getgrav.org/download/core/grav-admin/${GRAV_VERSION} && \
    unzip grav-admin.zip && \
    mv -T /var/www/grav-admin /var/www/html && \
    rm grav-admin.zip

# Create cron job for Grav maintenance scripts
RUN (crontab -l; echo "* * * * * cd /var/www/html;/usr/local/bin/php bin/grav scheduler 1>> /dev/null 2>&1") | crontab -

# Return to root user
USER root

# Copy init scripts
# COPY docker-entrypoint.sh /entrypoint.sh

# provide container inside image for data persistence
VOLUME ["/var/www/html"]

# ENTRYPOINT ["/entrypoint.sh"]
# CMD ["apache2-foreground"]
CMD ["sh", "-c", "cron && apache2-foreground"]
