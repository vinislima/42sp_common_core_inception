## @file Dockerfile
## @brief WordPress + php-fpm service image for the Inception project.
## @note Base: Debian 12 (bookworm), the penultimate Debian stable release.
##       No NGINX in this image: this container only runs php-fpm.
FROM debian:bookworm

## @brief Install php-fpm, the PHP extensions WordPress needs, wp-cli's
##        runtime (php-cli, curl) and a MariaDB client for healthchecks.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        php8.2-fpm php8.2-cli php8.2-mysql php8.2-curl php8.2-gd \
        php8.2-mbstring php8.2-xml php8.2-zip \
        curl ca-certificates default-mysql-client less && \
    rm -rf /var/lib/apt/lists/*

## @brief Install WP-CLI: the official WordPress command-line tool.
## @note This downloads a CLI script, not a Docker image, so it does not
##       violate the "no ready-made Docker images" rule.
RUN curl -o /usr/local/bin/wp -sSL \
        https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x /usr/local/bin/wp

## @brief Download WordPress core at build time into a template directory.
## @note Not /var/www/html directly: that path will be an empty volume at
##       first container start, which would hide anything copied here at
##       build time. The entrypoint copies from /usr/src/wordpress into the
##       volume only on the very first run.
RUN wp core download --path=/usr/src/wordpress --locale=en_US --allow-root

## @brief php-fpm pool config: listens on TCP 9000 for NGINX's fastcgi_pass.
COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf
## @brief Entrypoint script: waits for MariaDB, installs/configures
##        WordPress on first run, then execs php-fpm in the foreground.
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /var/www/html
## @brief WordPress core, plugins, themes and uploads live here, persisted
##        by a named volume shared (read-only) with the NGINX container.
VOLUME ["/var/www/html"]
## @brief FastCGI port; only reachable from other containers on the
##        "inception" network, never published to the host.
EXPOSE 9000

## @brief exec-form entrypoint: keeps the script as PID 1 for correct signal handling.
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
