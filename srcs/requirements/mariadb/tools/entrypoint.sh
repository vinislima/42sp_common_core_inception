#!/bin/bash
## @file entrypoint.sh
## @brief Idempotent startup script for the MariaDB container.
## @note On first run (empty data directory) it starts a temporary
##       mariadbd instance bound ONLY to a local Unix socket (no
##       networking) to run the setup SQL through a normal `mariadb`
##       client connection. `mariadbd --bootstrap` was tried first, but
##       on MariaDB 10.11 that mode implies --skip-grant-tables, which
##       rejects ALTER USER/CREATE USER/GRANT — so it cannot be used
##       here. The temporary server is cleanly shut down afterwards, and
##       only then does the script exec the real mariadbd as PID 1.
set -euo pipefail

DATADIR=/var/lib/mysql
SOCKET=/run/mysqld/mysqld.sock

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

	## @brief Temporary server, socket-only (--skip-networking): nothing on
	##        the network can reach it, and it only exists for this setup
	##        step — it is cleanly shut down below before the real server
	##        (PID 1) starts.
	echo "[mariadb-entrypoint] Starting temporary server (socket only) to apply setup SQL..."
	mariadbd --user=mysql --datadir="${DATADIR}" --socket="${SOCKET}" --skip-networking &
	tmp_pid=$!

	## @brief Bounded wait (max 30s) for the temporary server's socket to
	##        accept connections — never an unbounded/infinite loop.
	tries=0
	until mariadb-admin --socket="${SOCKET}" ping --silent >/dev/null 2>&1; do
		tries=$((tries + 1))
		if [ "${tries}" -ge 30 ]; then
			echo "[mariadb-entrypoint] ERROR: temporary server did not respond in time" >&2
			exit 1
		fi
		sleep 1
	done

	## @note Heredoc delimiter is quoted ('SQL'), so the shell does NOT
	##       expand $, ` or \ inside it — a password containing shell
	##       metacharacters can never be executed as a command here. The
	##       passwords are substituted afterwards as plain text, already
	##       SQL-escaped by sql_escape().
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

	## @brief Apply via a normal `mariadb` client connection (not bootstrap
	##        mode), which has full access to the grant tables. Freshly
	##        installed root@localhost uses unix_socket auth, so no
	##        password is needed yet (we are running as the OS "root" user).
	printf '%s\n' "${SETUP_SQL}" | mariadb --socket="${SOCKET}" -u root

	echo "[mariadb-entrypoint] Shutting down temporary server..."
	mariadb-admin --socket="${SOCKET}" -u root -p"${DB_ROOT_PASSWORD}" shutdown
	wait "${tmp_pid}" 2>/dev/null || true

	echo "[mariadb-entrypoint] Initialization complete."
else
	echo "[mariadb-entrypoint] Data directory already exists, skipping initialization."
fi

## @brief Hand off to mariadbd in the foreground: it becomes the container's PID 1.
echo "[mariadb-entrypoint] Starting MariaDB in the foreground (PID 1)..."
exec mariadbd --user=mysql --datadir="${DATADIR}" --bind-address=0.0.0.0
