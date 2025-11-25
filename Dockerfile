# Use the official FrankenPHP image as base
FROM dunglas/frankenphp:1.9-php8.2-alpine

# Install system dependencies
RUN apk add --no-cache \
    git \
    unzip \
    libzip-dev \
    oniguruma-dev \
    curl \
    icu-dev \
    gcc \
    g++ \
    make \
    autoconf \
    && docker-php-ext-install \
        zip \
        mbstring \
        intl \
        mysqli \
        pdo \
        pdo_mysql

# Install excimer extension
RUN pecl install excimer \
    && docker-php-ext-enable excimer pdo_mysql \
    && php -m | grep -i excimer

# Set working directory
WORKDIR /var/www/html

# Copy composer files first for better layer caching
COPY composer.json composer.lock ./

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Install PHP dependencies (production only)
RUN composer install --no-dev --optimize-autoloader --no-scripts --no-interaction

# Copy application source code
COPY . .

# Create var directory structure and set proper permissions
RUN mkdir -p var/cache var/log \
    && chown -R www-data:www-data var/ \
    && chmod -R 755 var/

# Install production dependencies and optimize
RUN composer install --no-dev --optimize-autoloader --no-scripts --no-interaction \
    && composer dump-autoload --optimize --no-dev --classmap-authoritative \
    && composer symfony:dump-env prod --no-scripts

# Clear cache and warm up for production (skip if console commands fail)
RUN php bin/console cache:clear --env=prod --no-debug --no-warmup || true \
    && php bin/console cache:warmup --env=prod --no-debug || true

# Copy FrankenPHP configuration
COPY frankenphp/Caddyfile/Caddyfile /etc/caddy/Caddyfile

# Create production PHP configuration
RUN echo '[PHP]' > /usr/local/etc/php/conf.d/20-app.ini && \
    echo 'display_errors = Off' >> /usr/local/etc/php/conf.d/20-app.ini && \
    echo 'log_errors = On' >> /usr/local/etc/php/conf.d/20-app.ini && \
    echo 'error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT & ~E_NOTICE & ~E_WARNING' >> /usr/local/etc/php/conf.d/20-app.ini && \
    echo 'memory_limit = 512M' >> /usr/local/etc/php/conf.d/20-app.ini && \
    echo 'max_execution_time = 60' >> /usr/local/etc/php/conf.d/20-app.ini && \
    echo 'date.timezone = UTC' >> /usr/local/etc/php/conf.d/20-app.ini && \
    echo 'opcache.enable = 1' >> /usr/local/etc/php/conf.d/20-app.ini && \
    echo 'opcache.memory_consumption = 256' >> /usr/local/etc/php/conf.d/20-app.ini && \
    echo 'opcache.max_accelerated_files = 10000' >> /usr/local/etc/php/conf.d/20-app.ini && \
    echo 'opcache.revalidate_freq = 0' >> /usr/local/etc/php/conf.d/20-app.ini && \
    echo 'opcache.fast_shutdown = 1' >> /usr/local/etc/php/conf.d/20-app.ini && \
    echo 'opcache.validate_timestamps = 0' >> /usr/local/etc/php/conf.d/20-app.ini

# Create log directories
RUN mkdir -p /var/log \
    && chown -R www-data:www-data /var/log

# Expose port 80
EXPOSE 80

# Start FrankenPHP
CMD ["frankenphp", "run", "--config", "/etc/caddy/Caddyfile"]
