#!/bin/bash
## @file entrypoint.sh
## @brief Idempotent startup script for the WordPress + php-fpm container.
## @note On first run (empty volume) it copies WordPress core, generates
##       wp-config.php, installs WordPress non-interactively (no setup
##       wizard) and creates an admin plus a second regular user. Then it
##       hands off to php-fpm in the foreground as PID 1.
set -euo pipefail

WP_PATH=/var/www/html

## @brief Read passwords from Docker secrets, never from env vars or the image.
DB_PASSWORD="$(cat /run/secrets/db_password)"
WP_ADMIN_PASSWORD="$(cat /run/secrets/wp_admin_password)"
WP_USER_PASSWORD="$(cat /run/secrets/wp_user_password)"

## @brief Wait for MariaDB to accept authenticated connections.
## @note Bounded retry loop (30 tries) — never an infinite loop/daemon hack.
##       Using MYSQL_USER/DB_PASSWORD here also implicitly waits for the
##       MariaDB entrypoint to have finished creating that user.
echo "[wordpress-entrypoint] Waiting for MariaDB..."
tries=0
until mariadb-admin --host=mariadb --user="${MYSQL_USER}" --password="${DB_PASSWORD}" ping --silent >/dev/null 2>&1; do
	tries=$((tries + 1))
	if [ "${tries}" -ge 30 ]; then
		echo "[wordpress-entrypoint] ERROR: MariaDB did not respond in time" >&2
		exit 1
	fi
	sleep 2
done
echo "[wordpress-entrypoint] MariaDB is available."

## @brief First boot: the volume is empty, so copy the WordPress core files
##        that were downloaded at build time into /usr/src/wordpress.
if [ ! -f "${WP_PATH}/wp-settings.php" ]; then
	echo "[wordpress-entrypoint] Copying WordPress files into the volume..."
	cp -a /usr/src/wordpress/. "${WP_PATH}/"
fi

cd "${WP_PATH}"

## @brief Generate wp-config.php from environment variables and secrets.
if [ ! -f wp-config.php ]; then
	echo "[wordpress-entrypoint] Generating wp-config.php..."
	wp config create \
		--allow-root \
		--dbname="${MYSQL_DATABASE}" \
		--dbuser="${MYSQL_USER}" \
		--dbpass="${DB_PASSWORD}" \
		--dbhost=mariadb \
		--skip-check
fi

## @brief Run the actual install only once: this is what skips the
##        browser-based WordPress setup wizard entirely.
if ! wp core is-installed --allow-root >/dev/null 2>&1; then
	echo "[wordpress-entrypoint] Installing WordPress (wp core install)..."
	wp core install --allow-root \
		--url="https://${DOMAIN_NAME}" \
		--title="${WP_TITLE}" \
		--admin_user="${WP_ADMIN_USER}" \
		--admin_password="${WP_ADMIN_PASSWORD}" \
		--admin_email="${WP_ADMIN_EMAIL}" \
		--skip-email

	## @brief Second, non-administrator user required by the subject.
	echo "[wordpress-entrypoint] Creating second (non-admin) user..."
	wp user create --allow-root \
		"${WP_USER}" "${WP_USER_EMAIL}" \
		--role=author \
		--user_pass="${WP_USER_PASSWORD}"
else
	echo "[wordpress-entrypoint] WordPress already installed, skipping setup."
fi

## @brief php-fpm workers run as www-data; make sure they own the site files.
chown -R www-data:www-data "${WP_PATH}"

## @brief Hand off to php-fpm in the foreground: it becomes the container's PID 1.
echo "[wordpress-entrypoint] Starting php-fpm in the foreground (PID 1)..."
exec php-fpm8.2 -F
