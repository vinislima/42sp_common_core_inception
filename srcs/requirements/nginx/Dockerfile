## @file Dockerfile
## @brief NGINX service image for the Inception project.
## @note Base: Debian 12 (bookworm), the penultimate Debian stable release.
##       This is the ONLY container exposed to the host, over TLS on 443.
FROM debian:bookworm

## @brief Install NGINX and OpenSSL (used at build time to self-sign a cert).
RUN apt-get update && \
    apt-get install -y --no-install-recommends nginx openssl && \
    rm -rf /var/lib/apt/lists/*

## @param DOMAIN_NAME Site domain, injected from srcs/.env via
##        docker-compose.yml's build.args. Used as the certificate's CN
##        and substituted into the vhost's server_name below.
ARG DOMAIN_NAME=vinda-si.42.fr

## @brief Generate a self-signed TLS certificate at build time.
## @note This is not a password/secret, so it does not break the
##       "no password in Dockerfiles" rule.
RUN mkdir -p /etc/nginx/ssl && \
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/nginx/ssl/inception.key \
        -out /etc/nginx/ssl/inception.crt \
        -subj "/C=BR/ST=SP/L=SaoPaulo/O=42/OU=Inception/CN=${DOMAIN_NAME}"

## @brief Install the vhost, replacing the placeholder with the real domain,
##        and disable Debian's default site (avoids a stray port-80 vhost).
COPY conf/nginx.conf.template /etc/nginx/sites-available/wordpress.conf
RUN sed -i "s/__DOMAIN_NAME__/${DOMAIN_NAME}/" /etc/nginx/sites-available/wordpress.conf && \
    rm -f /etc/nginx/sites-enabled/default && \
    ln -s /etc/nginx/sites-available/wordpress.conf /etc/nginx/sites-enabled/wordpress.conf

## @brief Only port exposed by the whole stack; TLS-only (see nginx.conf.template).
EXPOSE 443

## @brief Run NGINX in the foreground so it stays the container's PID 1.
CMD ["nginx", "-g", "daemon off;"]
