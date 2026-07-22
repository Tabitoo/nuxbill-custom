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

This fork ships a ready-to-use Docker setup: PHP 8.2 + Apache, MySQL, and cron
all run in containers, so `docker compose up -d` is the only step needed on a
fresh Linux server.

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
   needed) to real values — don't leave the `change_me` placeholders.

3. Build and start the stack:

   ```bash
   docker compose up -d
   ```

   This builds the app image (PHP 8.2, Apache, the `gd`/`pdo_mysql`/`zip`/
   `mbstring`/`curl` extensions, and cron+supervisord running
   `system/cron.php` every 5 minutes and `system/cron_reminder.php` daily
   at 7 AM — matching the schedule PHPNuxBill itself recommends in
   Settings > App) and a MySQL 8 container with its data persisted in the
   `mysql_data` volume.

4. Open `http://<server-ip>/install/` in a browser and complete the web
   installer. When asked for the database host, use `mysql` (the Docker
   Compose service name, not `localhost`) along with the credentials you set
   in `.env`.

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
