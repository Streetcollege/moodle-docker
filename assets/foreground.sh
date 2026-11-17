#!/bin/bash

# pass environment to cron
declare -p | grep -Ev 'BASHOPTS|BASH_VERSINFO|EUID|PPID|SHELLOPTS|UID' > /container.env
service cron start

if ! [ "$MOODLE_DOCKER_DEV_MODE" = true ]; then
    echo 'display_errors = Off' >> /usr/local/etc/php/php.ini
fi


# Explicit names let Certbot match both certificate domains on first start.
export APACHE_DOCUMENT_ROOT="${APACHE_DOCUMENT_ROOT:-/var/www/html}"
if [ -n "${MOODLE_DOCKER_WEB_HOST:-}" ]; then
    SC_DEFAULT_VHOST="/etc/apache2/sites-available/000-default.conf"
    sed -i -E '/^[[:space:]]*Server(Name|Alias)[[:space:]]/d' "$SC_DEFAULT_VHOST"
    sed -i "/<VirtualHost \*:80>/a\\    ServerName ${MOODLE_DOCKER_WEB_HOST}\\n    ServerAlias www.${MOODLE_DOCKER_WEB_HOST#www.}" "$SC_DEFAULT_VHOST"
fi

# start letsencrypt certbot
certbot --apache --non-interactive --agree-tos --no-redirect \
    -d "$MOODLE_DOCKER_WEB_HOST" \
    -d "www.${MOODLE_DOCKER_WEB_HOST#www.}" \
    -m "$MOODLE_DOCKER_ADMIN_EMAIL"

# wait until outbound port is freed
while netstat -tulpn | grep ":80\s" > /dev/null;
do
    sleep 5
    apachectl -k graceful-stop
    echo "Waiting for outbound port to be free..."
done

echo "Starting Apache foreground process..."
apache2-foreground
