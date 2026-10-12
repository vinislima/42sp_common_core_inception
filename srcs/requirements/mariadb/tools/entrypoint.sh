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

## @brief Escapes a value for safe use inside a single-quoted SQL string
##        literal. MariaDB's default sql_mode treats backslash as an
##        escape character, so it must be escaped first, then the quote.
sql_escape() {
	local s=$1
	s=${s//\\/\\\\}
	s=${s//\'/\\\'}
	printf '%s' "$s"
}

## @brief Bind-mounted host volumes belong to the host user; reclaim
##        ownership for "mysql" before mariadbd tries to read/write it.
chown -R mysql:mysql "${DATADIR}"

if [ ! -d "${DATADIR}/mysql" ]; then
	## @brief First boot: the volume is empty, so initialize the data directory.
	echo "[mariadb-entrypoint] First start: initializing data directory..."
	mariadb-install-db --user=mysql --datadir="${DATADIR}" >/dev/null

	## @brief Apply the setup SQL in bootstrap mode: same mechanism
	##        mariadb-install-db itself uses to seed the system tables.
	##        The heredoc delimiter is quoted ('SQL'), so the shell does
	##        NOT expand $, ` or \ inside it — a password containing shell
	##        metacharacters can never be executed as a command here. The
	##        passwords are substituted afterwards as plain text, already
	##        SQL-escaped by sql_escape().
	echo "[mariadb-entrypoint] Applying setup SQL (mariadbd --bootstrap)..."
	DB_ROOT_PASSWORD_ESC="$(sql_escape "${DB_ROOT_PASSWORD}")"
	DB_PASSWORD_ESC="$(sql_escape "${DB_PASSWORD}")"

	SETUP_SQL=$(cat <<'SQL'
ALTER USER 'root'@'localhost' IDENTIFIED BY '__DB_ROOT_PASSWORD__';
CREATE DATABASE IF NOT EXISTS `__MYSQL_DATABASE__`;
CREATE USER IF NOT EXISTS '__MYSQL_USER__'@'%' IDENTIFIED BY '__DB_PASSWORD__';
GRANT ALL PRIVILEGES ON `__MYSQL_DATABASE__`.* TO '__MYSQL_USER__'@'%';
FLUSH PRIVILEGES;
SQL
)
	SETUP_SQL=${SETUP_SQL//__DB_ROOT_PASSWORD__/$DB_ROOT_PASSWORD_ESC}
	SETUP_SQL=${SETUP_SQL//__DB_PASSWORD__/$DB_PASSWORD_ESC}
	SETUP_SQL=${SETUP_SQL//__MYSQL_DATABASE__/$MYSQL_DATABASE}
	SETUP_SQL=${SETUP_SQL//__MYSQL_USER__/$MYSQL_USER}

	printf '%s\n' "${SETUP_SQL}" | mariadbd --user=mysql --datadir="${DATADIR}" --bootstrap

	echo "[mariadb-entrypoint] Initialization complete."
else
	echo "[mariadb-entrypoint] Data directory already exists, skipping initialization."
fi

## @brief Hand off to mariadbd in the foreground: it becomes the container's PID 1.
echo "[mariadb-entrypoint] Starting MariaDB in the foreground (PID 1)..."
exec mariadbd --user=mysql --datadir="${DATADIR}" --bind-address=0.0.0.0
