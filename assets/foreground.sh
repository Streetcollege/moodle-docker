#!/bin/bash

# pass environment to cron
declare -p | grep -Ev 'BASHOPTS|BASH_VERSINFO|EUID|PPID|SHELLOPTS|UID' > /container.env
service cron start

if ! [ "$MOODLE_DOCKER_DEV_MODE" = true ]; then
    echo 'display_errors = Off' >> /usr/local/etc/php/php.ini
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
