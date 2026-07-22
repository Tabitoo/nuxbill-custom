# Use the official PHP image with Apache
FROM php:8.2-apache
EXPOSE 80

# Install necessary PHP extensions and system packages (cron + supervisor
# so the container can run web + scheduled tasks together)
RUN apt-get update && apt-get install -y \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    zlib1g-dev \
    libzip-dev \
    libonig-dev \
    libcurl4-openssl-dev \
    zip \
    unzip \
    cron \
    supervisor \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd \
    && docker-php-ext-install pdo pdo_mysql \
    && docker-php-ext-install zip \
    && docker-php-ext-install mbstring \
    && docker-php-ext-install curl \
    && rm -rf /var/lib/apt/lists/*

# copy contents into directory
COPY . /var/www/html

# Set appropriate permissions
RUN chown -R www-data:www-data /var/www/html
RUN chmod -R 755 /var/www/html

# Set working directory
WORKDIR /var/www/html

# Cron jobs: system/cron.php hourly, system/cron_reminder.php daily
COPY crontab /etc/cron.d/phpnuxbill
RUN chmod 0644 /etc/cron.d/phpnuxbill && touch /var/log/cron.log

# supervisord runs Apache and cron together as the container's single process
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
