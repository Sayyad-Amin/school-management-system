# Use PHP 8.1 FPM as the base image
FROM php:8.1-fpm

# Set working directory
WORKDIR /var/www/html

# Install system dependencies required by Laravel and common PHP extensions
RUN apt-get update && apt-get install -y \
    build-essential \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    locales \
    zip \
    jpegoptim optipng pngquant gifsicle \
    vim \
    unzip \
    git \
    curl \
    # Ensure libzip-dev is installed early for zip extension
    libzip-dev \
    libonig-dev \
    libxml2-dev \
    # Dependencies for gd
    libgd-dev \
    # Dependencies for pdo_mysql
    libmariadb-dev \
    # Add autoconf for build configuration
    autoconf \
    # Node.js (Install LTS version) and npm
    curl \
    && curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y nodejs \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install PHP extensions using the more robust install-php-extensions script
# See https://github.com/mlocati/docker-php-extension-installer
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/
RUN install-php-extensions \
    zip \
    pdo_mysql \
    mbstring \
    exif \
    pcntl \
    bcmath \
    gd \
    dom \
    xml \
    ctype \
    opcache # Let the script handle enabling opcache if needed

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Copy existing application directory contents
COPY . /var/www/html

# Copy package files and install Node dependencies
COPY package.json package-lock.json ./
RUN npm install

# Copy composer file (ignore lock file for update)
COPY composer.json ./
# Remove existing lock file if present and run install (effectively an update)
RUN rm -f composer.lock && \
    composer install --no-interaction --optimize-autoloader --no-dev

# Copy application code again to ensure latest changes are included
# (Composer/NPM install might modify files, including the new composer.lock)
COPY . /var/www/html

# Build frontend and backend assets
RUN npm run frontend-production
RUN npm run backend-production

# Copy .env file from example, or expect it to be mounted
RUN php -r "file_exists('.env') || copy('.env.example', '.env');"
# Generate application key (important!)
RUN php artisan key:generate

# Set permissions for storage and bootstrap cache
RUN chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache
RUN chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

# Expose port 9000 and start php-fpm server
EXPOSE 9000
CMD ["php-fpm"]
