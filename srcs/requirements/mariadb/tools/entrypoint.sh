#!/bin/bash
## @file entrypoint.sh
## @brief Idempotent startup script for the MariaDB container.
## @note On first run (empty data directory) it initializes the database and
##       creates the WordPress database/user from Docker secrets by feeding
##       SQL directly to `mariadbd --bootstrap`: a single foreground process
##       that reads statements from stdin and exits on its own once done —
##       no networking is opened and nothing is ever run in the background.
##       It then hands off to `mariadbd` in the foreground as PID 1.
set -euo pipefail

DATADIR=/var/lib/mysql

## @brief Read passwords from Docker secrets, never from env vars or the image.
DB_ROOT_PASSWORD="$(cat /run/secrets/db_root_password)"
DB_PASSWORD="$(cat /run/secrets/db_password)"

## @brief Bind-mounted host volumes belong to the host user; reclaim
##        ownership for "mysql" before mariadbd tries to read/write it.
chown -R mysql:mysql "${DATADIR}"

if [ ! -d "${DATADIR}/mysql" ]; then
	## @brief First boot: the volume is empty, so initialize the data directory.
	echo "[mariadb-entrypoint] First start: initializing data directory..."
	mariadb-install-db --user=mysql --datadir="${DATADIR}" >/dev/null

	## @brief Apply the setup SQL in bootstrap mode: same mechanism
	##        mariadb-install-db itself uses to seed the system tables.
	echo "[mariadb-entrypoint] Applying setup SQL (mariadbd --bootstrap)..."
	mariadbd --user=mysql --datadir="${DATADIR}" --bootstrap <<SQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
SQL

	echo "[mariadb-entrypoint] Initialization complete."
else
	echo "[mariadb-entrypoint] Data directory already exists, skipping initialization."
fi

## @brief Hand off to mariadbd in the foreground: it becomes the container's PID 1.
echo "[mariadb-entrypoint] Starting MariaDB in the foreground (PID 1)..."
exec mariadbd --user=mysql --datadir="${DATADIR}" --bind-address=0.0.0.0
