## @file Dockerfile
## @brief MariaDB service image for the Inception project.
## @note Base: Debian 12 (bookworm), the penultimate Debian stable release
##       (current stable is 13/trixie). Pinned explicitly: "latest" is
##       forbidden by the subject.
FROM debian:bookworm

## @brief Install MariaDB server and client only (no other service in this image).
RUN apt-get update && \
    apt-get install -y --no-install-recommends mariadb-server mariadb-client && \
    rm -rf /var/lib/apt/lists/*

## @brief Custom server config, applied after Debian's defaults (99- prefix).
COPY conf/my.cnf /etc/mysql/mariadb.conf.d/99-inception.cnf
## @brief Entrypoint script: idempotent DB init + exec mariadbd in foreground.
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh

## @brief Prepare runtime dirs (socket, data dir) and make the entrypoint executable.
RUN mkdir -p /run/mysqld /var/lib/mysql && \
    chown -R mysql:mysql /run/mysqld /var/lib/mysql && \
    chmod +x /usr/local/bin/entrypoint.sh

## @brief Persistent MariaDB data directory (bound to a named volume via compose).
VOLUME ["/var/lib/mysql"]
## @brief Internal port only; never published to the host directly.
EXPOSE 3306

## @brief exec-form entrypoint: keeps the script as PID 1 for correct signal handling.
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
