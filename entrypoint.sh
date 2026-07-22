#!/bin/sh
set -e

touch /var/log/cron.log
mkdir -p /data

# /data is bind-mounted from the host and survives image rebuilds.
# Restore a previously installed config.php (if any) so a rebuild doesn't
# force the web installer to run again. config-sync.sh keeps /data/config.php
# up to date afterwards.
if [ -s /data/config.php ]; then
    cp /data/config.php /var/www/html/config.php
    chown www-data:www-data /var/www/html/config.php
fi

exec supervisord -c /etc/supervisor/conf.d/supervisord.conf
