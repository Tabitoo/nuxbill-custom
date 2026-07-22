FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    freeradius \
    freeradius-mysql \
    freeradius-utils \
    gettext-base \
    && rm -rf /var/lib/apt/lists/*

COPY sql.conf.template /etc/freeradius/3.0/mods-available/sql
COPY client-mikrotik.conf.template /etc/freeradius/3.0/client-mikrotik.conf.template
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# 1812/udp: authentication, 1813/udp: accounting
EXPOSE 1812/udp 1813/udp

ENTRYPOINT ["/entrypoint.sh"]
