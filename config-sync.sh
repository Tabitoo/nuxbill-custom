#!/bin/sh
# Keeps /data/config.php (bind-mounted, survives image rebuilds) in sync
# with /var/www/html/config.php (written once by the web installer).
set -e

while true; do
    if [ -s /var/www/html/config.php ] && ! cmp -s /var/www/html/config.php /data/config.php 2>/dev/null; then
        cp /var/www/html/config.php /data/config.php
    fi
    sleep 5
done
