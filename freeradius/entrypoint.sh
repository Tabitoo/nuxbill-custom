#!/bin/sh
set -e

VARS='${RADIUS_DB_HOST} ${RADIUS_DB_PORT} ${RADIUS_DB_USER} ${RADIUS_DB_PASSWORD} ${RADIUS_DB_NAME}'
envsubst "$VARS" < /etc/freeradius/3.0/mods-available/sql > /tmp/sql.conf
mv /tmp/sql.conf /etc/freeradius/3.0/mods-available/sql

ln -sf ../mods-available/sql /etc/freeradius/3.0/mods-enabled/sql

VARS='${RADIUS_CLIENT_NETWORK} ${RADIUS_SECRET}'
envsubst "$VARS" < /etc/freeradius/3.0/client-mikrotik.conf.template > /tmp/client-mikrotik.conf
cat /tmp/client-mikrotik.conf >> /etc/freeradius/3.0/clients.conf
rm /tmp/client-mikrotik.conf

chown -R freerad:freerad /etc/freeradius/3.0/mods-enabled /etc/freeradius/3.0/mods-available/sql

exec freeradius -f -l stdout
