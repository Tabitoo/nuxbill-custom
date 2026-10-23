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

> **Production checklist (Spanish):** [docs/DESPLIEGUE.md](docs/DESPLIEGUE.md)
> covers what's left for a full deployment: fixed domain with Cloudflare
> Tunnel, connecting the Mikrotik via API (same network or remote), backups
> and pending security tasks.

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
   docker compose up -d --build
   ```

   Use `--build` here even on a first install: if an image from a previous
   attempt is already cached locally under the same project name, plain
   `docker compose up -d` will silently reuse it instead of rebuilding from
   the current source.

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

**Behind HTTPS proxies / Cloudflare Tunnel:** if something in front of the
container terminates HTTPS and forwards plain HTTP to port 80 (e.g.
`cloudflared tunnel --url http://localhost:80`), Apache treats requests with
`X-Forwarded-Proto: https` as HTTPS (see `forwarded-proto.conf`), so CSS/JS
links are generated with `https://` and aren't blocked as mixed content. No
change to `config.php` is needed.

The dashboard may show "Cron appear not been setup" for the first few
minutes after a fresh `up` — that's expected until the first `system/cron.php`
run (every 5 minutes) writes its heartbeat file.

## Connecting the Mikrotik (RouterOS API)

This is the recommended way to connect a single Mikrotik to this stack.
PHPNuxBill talks to the router over the RouterOS API (TCP `8728`) and pushes
hotspot users / PPPoE secrets and their profiles directly into it; the router
then authenticates clients on its own. That means **clients keep working even
if the PHPNuxBill server is down or rebooting** — only new purchases and
expirations wait until it's back. (With FreeRADIUS, nobody can log in while
the server is down; it's mainly worth it with many routers. See
[Freeradius](#freeradius).)

Expirations are applied by `system/cron.php`, which already runs inside the
`nuxbill` container (see step 3 above) — nothing extra to set up.

**Docker needs no changes for this.** Outbound traffic from the `nuxbill`
container is routed through the host, so as soon as the host itself can reach
the Mikrotik (same LAN or through the WireGuard tunnel below), the app can too.
No inbound ports have to be opened on the server for the API either: it's the
server that connects to the router.

> The Cloudflare Tunnel only publishes the web page. It does **not** carry the
> API connection between the server and the Mikrotik.

### 1. Network between the server and the Mikrotik

Pick the case that applies.

**Case A — same local network.** Nothing to configure on the server besides
giving it a **fixed LAN IP** (e.g. a DHCP reservation), so the router can
restrict API access to it. Use the Mikrotik's LAN IP in step 3.

**Case B — different networks: WireGuard tunnel.** Don't expose port `8728`
to the internet. Instead, create a WireGuard tunnel (built into RouterOS 7)
and let the API listen only on it. The examples use `10.10.10.0/30`: the
Mikrotik is `10.10.10.1`, the server is `10.10.10.2`. The Mikrotik needs a
public IP (ideally static, or a DDNS name — RouterOS provides one for free
under `/ip cloud`); if the ISP puts it behind CGNAT, this setup won't work
as-is.

On the **Mikrotik**:

```
/interface wireguard add name=wg-nuxbill listen-port=13231
/ip address add address=10.10.10.1/30 interface=wg-nuxbill
/ip firewall filter add chain=input protocol=udp dst-port=13231 action=accept place-before=0 comment="WireGuard nuxbill"
/interface wireguard print
```

Write down the Mikrotik's `public-key` from the last command.

On the **server** (Debian/Ubuntu host, not inside a container):

```bash
sudo apt install wireguard
wg genkey | sudo tee /etc/wireguard/privatekey | wg pubkey | sudo tee /etc/wireguard/publickey
```

Create `/etc/wireguard/wg0.conf`:

```ini
[Interface]
PrivateKey = <contents of /etc/wireguard/privatekey>
Address = 10.10.10.2/30

[Peer]
PublicKey = <Mikrotik public-key>
Endpoint = <Mikrotik public IP or DDNS name>:13231
AllowedIPs = 10.10.10.1/32
PersistentKeepalive = 25
```

Enable it so it comes up on every boot:

```bash
sudo chmod 600 /etc/wireguard/wg0.conf /etc/wireguard/privatekey
sudo systemctl enable --now wg-quick@wg0
```

Back on the **Mikrotik**, register the server as a peer:

```
/interface wireguard peers add interface=wg-nuxbill public-key="<contents of the server's /etc/wireguard/publickey>" allowed-address=10.10.10.2/32
```

Check with `ping 10.10.10.1` from the server. The server starts the
connection and `PersistentKeepalive` keeps it up, so the server can stay
behind NAT with no port forwarding.

### 2. API user on the Mikrotik

Create a dedicated user and allow API access **only from the server**
(`<server-ip>` is its fixed LAN IP in case A, `10.10.10.2` in case B):

```
/user group add name=nuxbill policy=read,write,api,test,policy,sensitive
/user add name=nuxbill group=nuxbill password=<strong-password>
/ip service set api address=<server-ip>/32 disabled=no
```

Use the plain `api` service (`8728`), not `api-ssl`: PHPNuxBill's RouterOS
client doesn't open TLS connections. That's why the API goes through the LAN
or the tunnel, never straight over the internet.

Test that the app container can reach it (`<mikrotik-ip>` is the LAN IP in
case A, `10.10.10.1` in case B):

```bash
docker exec nuxbill bash -c "timeout 3 bash -c '</dev/tcp/<mikrotik-ip>/8728' && echo API OK"
```

### 3. Add the router in PHPNuxBill

1. Go to **Network → Routers → New Router** and fill in:
   - **Status:** Enable
   - **Router Name / Location:** any name (e.g. `Main`)
   - **IP Address:** `<mikrotik-ip>:8728` (e.g. `192.168.88.1:8728`, or
     `10.10.10.1:8728` with the tunnel)
   - **Username:** `nuxbill`
   - **Router Secret:** the password from step 2
   - Leave **Test Connection** checked: PHPNuxBill logs into the router
     before saving and shows the error if it can't.
2. Create the speed profiles in **Internet Plan → Bandwidth**.
3. For PPPoE, create the address pool in **Network → IP Pool** and pick that
   router.
4. Create the plans in **Internet Plan → Hotspot** and/or **Internet Plan →
   PPPOE**, choosing this router in **Router Name**. PHPNuxBill creates the
   matching hotspot user profile / PPP profile on the Mikrotik when you save.

From then on, when a customer gets a plan, PHPNuxBill creates their user on
the Mikrotik; when it expires, the cron job removes or disables it.

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
  and register your router as a NAS in **Radius → Radius NAS** (the menu
  appears once Radius is enabled), pointing the Mikrotik at this server's IP,
  port `1812`/`1813`, and `RADIUS_SECRET`.
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
