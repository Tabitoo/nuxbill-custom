[![ReadMeSupportPalestine](https://raw.githubusercontent.com/Safouene1/support-palestine-banner/master/banner-project.svg)](https://s.id/standwithpalestine)

# PHPNuxBill - PHP Mikrotik Billing

![PHPNuxBill](install/img/logo.png)

## Feature

- Voucher Generator and Print
- [Freeradius](https://github.com/hotspotbilling/phpnuxbill/wiki/FreeRadius)
- Self registration
- User Balance
- Auto Renewal Package using Balance
- Multi Router Mikrotik
- Hotspot & PPPOE
- Easy Installation
- Multi Language
- Payment Gateway
- SMS validation for login
- Whatsapp Notification to Consumer
- Telegram Notification for Admin

See [How it Works / Cara Kerja](https://github.com/hotspotbilling/phpnuxbill/wiki/How-It-Works---Cara-kerja)

## Payment Gateway And Plugin

- [Payment Gateway List](https://github.com/orgs/hotspotbilling/repositories?q=payment+gateway)
- [Plugin List](https://github.com/orgs/hotspotbilling/repositories?q=plugin)

You can download payment gateway and Plugin from Plugin Manager

## System Requirements

Most current web servers with PHP & MySQL installed will be capable of running PHPNuxBill

Minimum Requirements

- Linux or Windows OS
- Minimum PHP Version 8.2
- Both PDO & MySQLi Support
- PHP-GD2 Image Library
- PHP-CURL
- PHP-ZIP
- PHP-Mbstring
- MySQL Version 4.1.x and above

can be Installed in Raspberry Pi Device.

The problem with windows is hard to set cronjob, better Linux

## Changelog

[CHANGELOG.md](CHANGELOG.md)

## Installation

[Installation instructions](https://github.com/hotspotbilling/phpnuxbill/wiki) (manual, without Docker)

### Docker Installation (recommended)

This fork ships a ready-to-use Docker setup: PHP 8.2 + Apache, MySQL, cron and
a FreeRADIUS server all run in containers, so `docker compose up -d` is the
only step needed on a fresh Linux server.

**Requirements:** Docker and the Docker Compose plugin installed on the server.

1. Clone this repository on the target server:

   ```bash
   git clone https://github.com/Tabitoo/nuxbill-custom.git
   cd nuxbill-custom
   ```

2. Copy the environment template and set your own credentials:

   ```bash
   cp .env.example .env
   ```

   Edit `.env` and set `MYSQL_ROOT_PASSWORD`, `MYSQL_PASSWORD` (and `TZ` if
   needed) to real values — don't leave the `change_me` placeholders. Also set
   `RADIUS_SECRET` to a real shared secret, and `RADIUS_CLIENT_NETWORK` to
   your Mikrotik's IP/subnet (see §5 below) if you're using FreeRADIUS.

3. Build and start the stack:

   ```bash
   docker compose up -d
   ```

   This builds the app image (PHP 8.2, Apache, the `gd`/`pdo_mysql`/`zip`/
   `mbstring`/`curl` extensions, and cron+supervisord running
   `system/cron.php` every 5 minutes and `system/cron_reminder.php` daily
   at 7 AM — matching the schedule PHPNuxBill itself recommends in
   Settings > App), a MySQL 8 container with its data persisted in the
   `mysql_data` volume, and a FreeRADIUS container (see [Freeradius](#freeradius) below).

4. Open `http://<server-ip>/install/` in a browser and complete the web
   installer. When asked for the database host, use `mysql` (the Docker
   Compose service name, not `localhost`) along with the credentials you set
   in `.env`. Tick the "Install Radius" option if you want RADIUS-backed
   Hotspot/PPPoE from the start (see [Freeradius](#freeradius) below) — it just imports `install/radius.sql`
   into the same database.

**Persistence across rebuilds:** `/var/www/html` itself isn't a mounted
volume, so rebuilding the image (`docker compose up --build`, e.g. after
updating the theme in `ui/ui_custom`) discards anything written directly
into the container. Two things are carried over automatically regardless:

- `config.php`, written by the installer, is synced to `./data/config.php`
  on the host and restored on container start — you won't be asked to
  reinstall after a rebuild.
- `system/uploads` (voucher templates, uploaded logos, the cron heartbeat
  file the dashboard checks) lives in the `app_uploads` named volume.

The dashboard may show "Cron appear not been setup" for the first few
minutes after a fresh `up` — that's expected until the first `system/cron.php`
run (every 5 minutes) writes its heartbeat file.

## Freeradius

Support [Freeradius with Database](https://github.com/hotspotbilling/phpnuxbill/wiki/FreeRadius)

### Freeradius in this Docker setup

A `freeradius` service (`./freeradius/Dockerfile`, Debian + `freeradius`/
`freeradius-mysql`) runs alongside `nuxbill` and `mysql`, reading/writing the
same `radcheck`/`radreply`/`radgroupcheck`/`radgroupreply`/`radusergroup`/
`radacct`/`radpostauth`/`nas` tables PHPNuxBill itself uses (schema from
`install/phpnuxbill.sql`/`install/radius.sql`) — no separate database, no
sync needed between the two.

- **Ports:** `1812/udp` (authentication) and `1813/udp` (accounting) are
  published to the host, same as a normal FreeRADIUS install.
- **`.env` variables:**
  - `RADIUS_SECRET` — the shared secret. Set it to something real, and
    configure the exact same value on the Mikrotik's RADIUS client settings.
  - `RADIUS_CLIENT_NETWORK` — the IP or CIDR range your Mikrotik(s) connect
    from (e.g. `192.168.88.1` or `192.168.88.0/24`). Defaults to `0.0.0.0/0`
    (accepts requests from anywhere) for easy local testing — **tighten this
    to your actual router's address before going to production**, otherwise
    anyone who knows `RADIUS_SECRET` can authenticate against your server.
- **Enabling it in PHPNuxBill itself:** having the container running isn't
  enough on its own — in Settings, turn on "Use Radius" (`radius_enable`),
  and set up your router in Settings > Routers with the RADIUS option
  pointing at this server's IP, port `1812`/`1813`, and `RADIUS_SECRET`.
  `config.php` needs `$radius_host`/`$radius_user`/`$radius_pass`/`$radius_name`
  set (the installer does this automatically if you tick "Install Radius" in
  step 3 — they default to the same values as `$db_host`/etc. since it's the
  same database).
- **Rebuilds:** the `freeradius` container has no state of its own to lose —
  everything it reads lives in the `mysql_data` volume — so a
  `docker compose up --build` is safe and doesn't require reconfiguring
  anything.

## Community Support

- [Github Discussion](https://github.com/hotspotbilling/phpnuxbill/discussions)
- [Telegram Group](https://t.me/phpmixbill)

## Technical Support

This Software is Free and Open Source, Without any Warranty.

Even if the software is free, but Technical Support is not,
Technical Support Start from Rp 500.000 or $50

If you chat me for any technical support,
you need to pay,

ask anything for free in the [discussion](/hotspotbilling/phpnuxbill/discussions) page or [Telegram Group](https://t.me/phpnuxbill)

Contact me at [Telegram](https://t.me/ibnux)

## License

GNU General Public License version 2 or later

see [LICENSE](LICENSE) file


## Donate to ibnux

[![Donate](https://img.shields.io/badge/Donate-PayPal-green.svg)](https://paypal.me/ibnux)

BCA: 5410454825

Mandiri: 163-000-1855-793

a.n Ibnu Maksum

## SPONSORS

- [mixradius.com](https://mixradius.com/) Paid Services Billing Radius
- [mlink.id](https://mlink.id)
- [https://github.com/sonyinside](https://github.com/sonyinside)

## Thanks
We appreciate all people who are participating in this project.

<a href="https://github.com/hotspotbilling/phpnuxbill/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=hotspotbilling/phpnuxbill" />
</a>
