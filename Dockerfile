# =========================================================================
# STAGE 1: Build & Compile Extensions (Temporary Builder Container)
# =========================================================================
FROM php:8.2-fpm-alpine AS builder

# Prevent interactive prompts and allow composer superuser
ENV DEBIAN_FRONTEND=noninteractive
ENV COMPOSER_ALLOW_SUPERUSER=1

# Install Alpine system build utilities needed ONLY during compilation
RUN apk add --no-cache \
    git \
    curl \
    libpng-dev \
    oniguruma-dev \
    libxml2-dev \
    libzip-dev \
    zip \
    unzip

# Install official PHP extensions natively using Docker's helpers
RUN docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd xml zip

# Pull a clean binary version of Composer into our container
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Set the target folder inside the container
WORKDIR /var/www/html

# 1. Copy ALL your local project files into the container first
COPY . .

# 2. OBLITERATE host-copied files: Permanently erase your local vendor folder and stale cache files
RUN rm -rf vendor bootstrap/cache/*.php

# 3. Clean installation: Let Composer handle the full download, autoload mapping, and scripts natively inside the container
RUN composer install --no-dev --optimize-autoloader --no-interaction --prefer-dist

# Clean up development files before copying to the final runtime stage
RUN rm -rf tests README.md .git .github

# =========================================================================
# STAGE 2: Lightweight Runtime Environment (The Actual Final Image)
# =========================================================================
FROM php:8.2-fpm-alpine

WORKDIR /var/www/html

# Install ONLY the runtime shared libraries that PHP needs to function
RUN apk add --no-cache \
    libpng \
    oniguruma \
    libxml2 \
    libzip

# Copy compiled PHP extensions and configuration files directly from the builder stage
COPY --from=builder /usr/local/lib/php/extensions /usr/local/lib/php/extensions
COPY --from=builder /usr/local/etc/php/conf.d /usr/local/etc/php/conf.d

# Copy ONLY the fully optimized code and vendor files from the builder stage
COPY --from=builder /var/www/html /var/www/html

# Hand over storage folder access permissions to the internal web user
RUN chown -R www-data:www-data storage bootstrap/cache

# Standard port configuration for PHP-FPM communication
EXPOSE 9000

# Fire up the official native PHP-FPM runtime service smoothly
CMD ["php-fpm"]
