# Despliegue a producción de PHPNuxBill (este fork)

Guía de lo que falta para dejar el proyecto andando al 100% en el servidor del
cliente: publicar la página con un dominio fijo, conectar el Mikrotik por API
(en la misma red o en redes distintas) y cerrar los pendientes de seguridad.

La instalación base del stack (`.env`, `docker compose up -d --build`,
instalador web) está en el [README](../README.md#docker-installation-recommended).
Esta guía arranca desde ahí.

> **Estado del documento:** relevado sobre el repo el 2026-10-23. Las tareas
> marcadas `[x]` se comprobaron en los archivos indicados; el resto está
> pendiente y **todavía no se resolvió**, solo se documentó.

---

## 0. Cómo está armado el stack (lo que hay realmente en el repo)

| Servicio (compose) | Qué es | Puertos al host | Persistencia |
|---|---|---|---|
| `nuxbill` | PHP 8.2.35 + Apache + cron + supervisord (`Dockerfile`) | `80:80` | `./data` → `/data` (copia de `config.php`), volumen `app_uploads` → `/var/www/html/system/uploads` |
| `mysql` | MySQL 8.0 | ninguno (solo red interna de Compose) | volumen `mysql_data` |
| `freeradius` | FreeRADIUS 3 (`freeradius/Dockerfile`) | `1812/udp`, `1813/udp` | ninguna (lee todo de MySQL) |

- Dentro del contenedor `nuxbill`, `supervisord` (`supervisord.conf`) levanta
  tres procesos: Apache, `cron` y `config-sync.sh` (copia `config.php` a
  `/data/config.php` cada 5 s; `entrypoint.sh` lo restaura al arrancar).
- La app escucha en el puerto **80** del servicio **`nuxbill`**:
  - Desde el host: `http://localhost:80`
  - Desde otro contenedor del mismo compose: `http://nuxbill:80`
- El contenedor `nuxbill` sale a la red a través del host: todo lo que el host
  pueda alcanzar (LAN, túnel WireGuard/ZeroTier), la app también lo alcanza.
  **No hace falta tocar Docker para hablar con el Mikrotik.**

---

## 1. Lista de tareas

### Ya resueltas en el repo

- [x] **Cron de PHPNuxBill dentro de la imagen.** `system/cron.php` cada 5 min
  y `system/cron_reminder.php` a las 7:00. Comprobado en `crontab`,
  `supervisord.conf` (`[program:cron]`) y `Dockerfile` (`COPY crontab /etc/cron.d/phpnuxbill`).
- [x] **PHP actualizado y con las extensiones requeridas.** Fijado a
  `php:8.2.35-apache-bookworm` (parche de PHP2Shell, CVE-2026-109618/109619),
  con `gd`, `pdo_mysql`, `zip`, `mbstring`, `curl`. Comprobado en `Dockerfile`.
- [x] **Base de datos persistente.** Volumen `mysql_data` montado en
  `/var/lib/mysql`. Comprobado en `docker-compose.yml`.
- [x] **MySQL no expuesto al host.** El servicio `mysql` no tiene `ports:`.
  Comprobado en `docker-compose.yml`.
- [x] **`config.php` sobrevive a los rebuilds.** Comprobado en `entrypoint.sh`
  y `config-sync.sh` (bind mount `./data`).
- [x] **HTTPS detrás de Cloudflare Tunnel sin mixed content.** Apache marca como
  HTTPS las peticiones con `X-Forwarded-Proto: https`. Comprobado en
  `forwarded-proto.conf` y `Dockerfile` (`a2enconf forwarded-proto`).
- [x] **`.env` fuera de Git.** Comprobado en `.gitignore` (línea `.env`; también
  `config.php` y `/data/`).
- [x] **Reinicio automático de los contenedores.** `restart: unless-stopped` en
  los tres servicios. Comprobado en `docker-compose.yml`. (Docker tiene que
  estar habilitado al arranque del host: `sudo systemctl enable docker`.)

### Parcialmente resueltas

- [ ] **Zona horaria.** El compose pasa `TZ: ${TZ}` al contenedor `nuxbill`,
  pero:
  - `.env.example` trae `TZ=Africa/Nairobi`: hay que poner
    `TZ=America/Argentina/Buenos_Aires` (o la que corresponda) en el `.env` del
    servidor.
  - El servicio `mysql` no recibe `TZ`.
  - PHPNuxBill usa su propia zona para fechas y vencimientos
    (`init.php` → `date_default_timezone_set($config['timezone'])`): hay que
    elegirla también en **Settings → General Settings**.
  - Verificar que el cron corra a la hora local: `docker exec nuxbill date`
    tiene que mostrar la hora argentina (si muestra UTC, falta `tzdata` en la imagen).

### Pendientes

**Infraestructura y publicación**

- [ ] **Reconstruir con el PHP parcheado.** El commit ya está, pero el
  contenedor que corre en el servidor no cambia hasta reconstruirlo
  (ver [§5](#5-actualizar-el-servidor-tras-cambios-del-repo)).
- [ ] **Dominio fijo + túnel de Cloudflare con nombre** (ver [§2](#2-publicar-la-página-con-dominio-fijo-cloudflare-tunnel)).
- [ ] **(Opcional) `cloudflared` como servicio del compose**, para que el
  túnel también se levante con `docker compose up -d` (ver [§2.3](#23-opción-b-cloudflared-como-contenedor-del-compose)).
- [ ] **IP fija para el servidor** en su red local (reserva DHCP en el router).
- [ ] **Backups de la base de datos** (ver [§6](#6-backups)). Hoy no hay
  ninguno: si se pierde el disco o el volumen `mysql_data`, se pierde toda la
  facturación.

**Mikrotik**

- [ ] **Conectar el Mikrotik por API** (ver [§3](#3-conectar-el-mikrotik-por-api)).
- [ ] **Walled garden en el hotspot** para que un cliente sin plan pueda entrar
  a la página a comprar (ver [§3.5](#35-walled-garden-clientes-sin-plan-tienen-que-poder-entrar-a-la-página)).
- [ ] **Sacar FreeRADIUS del compose.** El servicio `freeradius` **sigue** en
  `docker-compose.yml` publicando `1812/udp` y `1813/udp`, y `.env.example`
  todavía pide `RADIUS_SECRET`/`RADIUS_CLIENT_NETWORK`. Como se eligió API, se
  puede quitar (y la carpeta `freeradius/`), o dejarlo pero sin publicar los
  puertos. Si alguna vez se vuelve a RADIUS, antes hay que corregir dos fallas
  (ver Notas de revisión).

**Seguridad**

- [x] **Evitar que `.env` y `data/` entren a la imagen.** Antes, el `.env` del
  servidor quedaba dentro de la imagen (`COPY . /var/www/html`) y Apache lo
  servía en `https://<dominio>/.env`. Resuelto en `.dockerignore` (excluye
  `.env`, `.env.*` y `data/`) y en `deny-dotfiles.conf` (Apache niega cualquier
  archivo que empiece con `.`), habilitado en el `Dockerfile`.
  **Hace falta reconstruir la imagen** para que aplique (ver [§5](#5-actualizar-el-servidor-tras-cambios-del-repo)).
- [ ] **Cambiar las contraseñas de MySQL**, porque el `.env` pudo haber quedado
  expuesto mientras la página estuvo publicada (ver [§7](#7-cambiar-las-contraseñas-de-mysql)).
- [x] **Bloquear `/install` después de instalar.** El instalador no verifica si
  ya existe un `config.php`, y la carpeta `install/` vuelve a copiarse en cada
  build. Resuelto en `block-installer.conf` (habilitado en el `Dockerfile`):
  cuando existe `config.php`, Apache niega los `.php`/`.sql` de `install/`,
  salvo `step5.php` (el último paso del instalador, que no toca la base ni
  `config.php`). **Hace falta reconstruir la imagen** para que aplique.
- [ ] **Persistir la carpeta `pages/`.** `install/step5.php` copia
  `pages_template/` a `pages/` (páginas editables como Términos, Privacidad,
  Anuncios). `pages/` no está en ningún volumen, así que **se pierde en cada
  rebuild** junto con lo que se haya editado desde el admin. Hay que montarla
  como volumen (como `system/uploads`) y que el `entrypoint.sh` la llene desde
  `pages_template/` si está vacía.
- [ ] **Cambiar la contraseña del admin** por defecto de PHPNuxBill
  (`admin` / `admin`) apenas termina la instalación.
- [ ] **Migrar a PHP 8.3 antes del 31/12/2026**, cuando PHP 8.2 deja de recibir
  parches de seguridad. Probar login, planes, cron y conexión al Mikrotik.
- [ ] **Firewall del host.** Con el túnel de Cloudflare no hace falta abrir
  ningún puerto de entrada. El `80` queda publicado en todas las interfaces
  (`80:80`): si no se va a entrar por la LAN, se puede limitar a
  `127.0.0.1:80:80` (o quitarlo si `cloudflared` va como contenedor).

**Contenido y cliente**

- [ ] **Confirmar qué HTML quiere editar el cliente** (pendiente de
  `CLAUDE.md`): el theme de PHPNuxBill (`ui/ui_custom`, entra en la imagen) o
  el login del hotspot del Mikrotik (vive en el router, no en la imagen).
- [ ] **Versionar el theme del cliente.** `ui/ui_custom/**` y `ui/themes/**`
  están en `.gitignore`: los archivos editados no se suben al repo, y un
  `git clone` en un servidor nuevo arma la imagen **sin** el theme.
- [ ] **(Si se cobra online) Gateway de pago**, por ejemplo MercadoPago. Ver
  `CUSTOMIZATION.md`. Necesita el dominio fijo para el webhook.

---

## 2. Publicar la página con dominio fijo (Cloudflare Tunnel)

El túnel rápido actual (`*.trycloudflare.com`) cambia de URL en cada
reinicio: sirve para pruebas, no para darle a los clientes. Con un dominio
propio y un **túnel con nombre**:

- El servidor no necesita IP pública ni abrir puertos (funciona detrás de NAT/CGNAT).
- HTTPS lo pone Cloudflare. El fix de mixed content ya está en la imagen.
- Clientes y admin usan la misma página: clientes en la raíz, admin en `/admin`.

### 2.1 Dominio y DNS

1. Comprar el dominio (`.com`, `.com.ar` en NIC Argentina, etc.).
2. Crear una cuenta gratis en Cloudflare, agregar el dominio y cambiar los
   nameservers en el registrador por los que indica Cloudflare.
3. Esperar a que Cloudflare marque el dominio como **Active**.

### 2.2 Opción A: `cloudflared` instalado en el host

1. En Cloudflare: **Zero Trust → Networks → Tunnels → Create a tunnel** →
   tipo *Cloudflared* → nombre (ej. `nuxbill`).
2. Elegir el sistema operativo del servidor y correr el comando que muestra:
   ```bash
   sudo cloudflared service install TOKEN-AQUI
   ```
   Queda como servicio de systemd y arranca solo con el servidor.
3. En **Public Hostname**:
   - Subdomain: `billing` (o el que se quiera), Domain: `tudominio.com`
   - Service: **HTTP** → `localhost:80`
4. Probar `https://billing.tudominio.com` y `https://billing.tudominio.com/admin`.
5. Apagar el túnel rápido de `trycloudflare` si sigue corriendo.

### 2.3 Opción B: `cloudflared` como contenedor del compose

Encaja mejor con el objetivo del proyecto (todo con `docker compose up -d`).
**No está implementado todavía**; quedaría así:

```yaml
  cloudflared:
    container_name: cloudflared
    image: cloudflare/cloudflared:VERSION-FIJA   # fijar una versión, no "latest"
    restart: unless-stopped
    command: tunnel --no-autoupdate run --token ${CLOUDFLARE_TUNNEL_TOKEN}
    depends_on:
      - nuxbill
```

- En `.env` (nunca en el repo): `CLOUDFLARE_TUNNEL_TOKEN=TOKEN-AQUI`, y agregar
  la variable vacía a `.env.example`.
- En el Public Hostname de Cloudflare, Service: **HTTP** → `nuxbill:80`
  (nombre del servicio en el compose, no `localhost`).
- Con esto se puede quitar el `ports: "80:80"` de `nuxbill` si no se entra por la LAN.

### 2.4 Después de cambiar de dominio

`config.php` arma `APP_URL` a partir del host de cada petición
(`$_SERVER['HTTP_HOST']`), así que **no hace falta editarlo** al pasar de la URL
de `trycloudflare` al dominio definitivo.

---

## 3. Conectar el Mikrotik por API

Se eligió **API** (no FreeRADIUS) porque es un solo Mikrotik y porque, si el
servidor se cae, los clientes siguen conectados: los usuarios ya están
cargados en el router. Detalles en el README:
[Connecting the Mikrotik (RouterOS API)](../README.md#connecting-the-mikrotik-routeros-api).

PHPNuxBill se conecta al Mikrotik por **TCP 8728** (API sin cifrar). Su
cliente RouterOS **no soporta `api-ssl` (8729)**, por eso la API nunca va
directo por internet: solo por la LAN o por un túnel.

### 3.1 Caso A: servidor y Mikrotik en la misma red

1. Darle **IP fija** al servidor (reserva DHCP). En los ejemplos: `IP-SERVIDOR`.
2. Anotar la IP LAN del Mikrotik. En los ejemplos: `IP-MIKROTIK` (ej. `192.168.88.1`).
3. Seguir con [§3.3](#33-usuario-api-en-el-mikrotik).

No hay nada más que configurar en el servidor.

### 3.2 Caso B: redes distintas

El servidor tiene que poder llegar al Mikrotik. Dos opciones:

#### Opción B1: WireGuard (recomendada)

Requisitos: RouterOS 7 y que el Mikrotik tenga **IP pública** (fija o con
DDNS gratis vía `/ip cloud set ddns-enabled=yes`). El servidor puede estar
detrás de NAT: él inicia la conexión.

Red del túnel: `10.10.10.0/30`. Mikrotik = `10.10.10.1`, servidor = `10.10.10.2`.

**En el Mikrotik:**
```
/interface wireguard add name=wg-nuxbill listen-port=13231
/ip address add address=10.10.10.1/30 interface=wg-nuxbill
/ip firewall filter add chain=input protocol=udp dst-port=13231 action=accept place-before=0 comment="WireGuard nuxbill"
/interface wireguard print
```
Anotar la `public-key` que muestra el último comando.

**En el servidor (host, no en un contenedor):**
```bash
sudo apt install wireguard
wg genkey | sudo tee /etc/wireguard/privatekey | wg pubkey | sudo tee /etc/wireguard/publickey
```

Crear `/etc/wireguard/wg0.conf`:
```ini
[Interface]
PrivateKey = CLAVE-PRIVADA-DEL-SERVIDOR-AQUI
Address = 10.10.10.2/30

[Peer]
PublicKey = CLAVE-PUBLICA-DEL-MIKROTIK-AQUI
Endpoint = IP-PUBLICA-O-DDNS-DEL-MIKROTIK:13231
AllowedIPs = 10.10.10.1/32
PersistentKeepalive = 25
```

```bash
sudo chmod 600 /etc/wireguard/wg0.conf /etc/wireguard/privatekey
sudo systemctl enable --now wg-quick@wg0
```

**De nuevo en el Mikrotik**, registrar al servidor:
```
/interface wireguard peers add interface=wg-nuxbill public-key="CLAVE-PUBLICA-DEL-SERVIDOR-AQUI" allowed-address=10.10.10.2/32
```

Probar desde el servidor: `ping 10.10.10.1`.

En los pasos siguientes: `IP-SERVIDOR` = `10.10.10.2`, `IP-MIKROTIK` = `10.10.10.1`.

#### Opción B2: ZeroTier (si el Mikrotik no tiene IP pública / está detrás de CGNAT)

ZeroTier arma una red privada atravesando NAT en ambos extremos, así que no
hace falta IP pública en ningún lado. Limitación: el paquete `zerotier` de
RouterOS 7 **solo existe para algunos modelos (ARM/ARM64)**; verificar el
modelo del cliente antes de elegir esta opción.

1. Crear una red en [my.zerotier.com](https://my.zerotier.com) y anotar el
   `ID-DE-RED-AQUI`.
2. **Mikrotik:** instalar el paquete `zerotier` (System → Packages), reiniciar y:
   ```
   /zerotier enable zt1
   /zerotier interface add network=ID-DE-RED-AQUI instance=zt1
   ```
3. **Servidor:**
   ```bash
   curl -s https://install.zerotier.com | sudo bash
   sudo zerotier-cli join ID-DE-RED-AQUI
   ```
4. En my.zerotier.com, **autorizar** los dos miembros y anotar las IPs que les
   asigna: esas son `IP-SERVIDOR` e `IP-MIKROTIK` para los pasos siguientes.
5. Probar desde el servidor: `ping IP-MIKROTIK`.

### 3.3 Usuario API en el Mikrotik

Usuario propio para PHPNuxBill y API abierta **solo** para el servidor:

```
/user group add name=nuxbill policy=read,write,api,test,policy,sensitive
/user add name=nuxbill group=nuxbill password=CONTRASEÑA-API-AQUI
/ip service set api address=IP-SERVIDOR/32 disabled=no
```

Si el router tiene reglas de firewall en `input` que bloquean todo, agregar
antes una que acepte TCP 8728 desde `IP-SERVIDOR`.

### 3.4 Cargar el router en PHPNuxBill

1. Probar que el contenedor llega a la API:
   ```bash
   docker exec nuxbill bash -c "timeout 3 bash -c '</dev/tcp/IP-MIKROTIK/8728' && echo API OK"
   ```
2. En PHPNuxBill: **Network → Routers → New Router**
   - **Status:** Enable
   - **Router Name / Location:** un nombre (ej. `Principal`)
   - **IP Address:** `IP-MIKROTIK:8728`
   - **Username:** `nuxbill`
   - **Router Secret:** la contraseña del paso anterior
   - Dejar tildado **Test Connection**: si no conecta, muestra el error y no guarda.
3. **Internet Plan → Bandwidth:** crear los perfiles de velocidad.
4. **Solo PPPoE:** crear el pool de IPs en **Network → IP Pool** con ese router.
5. **Internet Plan → Hotspot** y/o **Internet Plan → PPPOE:** crear los planes
   eligiendo el router en **Router Name**. Al guardar, PHPNuxBill crea el
   perfil correspondiente en el Mikrotik.

Desde ahí, cuando un cliente compra un plan, PHPNuxBill crea su usuario en el
Mikrotik, y cuando vence el cron lo quita o lo desactiva.

### 3.5 Walled garden: clientes sin plan tienen que poder entrar a la página

En el hotspot, un usuario sin plan (o vencido) no tiene internet, así que
tampoco llega a la página para comprar o renovar. Hay que permitir el dominio:

```
/ip hotspot walled-garden add dst-host=billing.tudominio.com
/ip hotspot walled-garden ip add dst-host=billing.tudominio.com action=accept
```

Con Cloudflare delante puede hacer falta permitir algún dominio extra de
Cloudflare. Probarlo con un dispositivo sin plan una vez que el router esté
conectado.

---

## 4. Checklist de verificación final

- [ ] `docker compose ps`: `nuxbill` y `mysql` en estado `running`.
- [ ] `docker exec nuxbill php -v` muestra `PHP 8.2.35` (o la versión vigente).
- [ ] `docker exec nuxbill date` muestra la hora local correcta.
- [ ] El dashboard de PHPNuxBill **no** muestra "Cron appear not been setup"
  (puede tardar 5 minutos después de un `up`).
- [ ] `https://billing.tudominio.com` carga con estilos, y `/admin` también.
- [ ] `https://billing.tudominio.com/.env` da **403/404**, no el archivo.
- [ ] `https://billing.tudominio.com/install/` da **403** (no muestra el instalador).
- [ ] `docker exec nuxbill apache2ctl -t` responde `Syntax OK`.
- [ ] El router aparece en **Network → Routers** y un plan de prueba crea el
  usuario en el Mikrotik (`/ip hotspot user print` o `/ppp secret print`).
- [ ] Un dispositivo sin plan, conectado al hotspot, puede abrir la página.
- [ ] Reiniciar el servidor completo: todo vuelve solo (Docker, túnel de
  Cloudflare, WireGuard/ZeroTier).
- [ ] Restaurar un backup de prueba en otra máquina.

---

## 5. Actualizar el servidor tras cambios del repo

```bash
cd nuxbill-custom
git pull
docker compose build --pull nuxbill
docker compose up -d
```

`--pull` baja la imagen base de PHP actualizada; sin eso Docker puede reusar
una vieja de la caché. `config.php` (en `./data`), la base (`mysql_data`) y
los uploads (`app_uploads`) se conservan.

---

## 6. Backups

No hay backups configurados todavía. Mínimo recomendado:

1. **Base de datos** (lo crítico): un dump diario desde el host, por ejemplo
   con cron del host o un servicio extra del compose:
   ```bash
   docker exec mysql sh -c 'exec mysqldump -u root -p"$MYSQL_ROOT_PASSWORD" --single-transaction "$MYSQL_DATABASE"' > backup-$(date +%F).sql
   ```
2. **`./data/config.php`** y el **`.env`** del servidor.
3. El volumen **`app_uploads`** (logos, plantillas de vouchers, facturas).
4. Guardar las copias **fuera del servidor** y rotarlas (ej. últimos 14 días).

---

## 7. Cambiar las contraseñas de MySQL

Las variables `MYSQL_*` del `.env` solo se usan **la primera vez** que se crea
el volumen `mysql_data`. Cambiarlas en el `.env` no cambia la contraseña real;
hay que hacerlo en tres lugares: MySQL, `config.php` y `.env`.

1. Primero reconstruir con el fix (§5) y comprobar que
   `https://billing.tudominio.com/.env` ya da **403**.
2. Cambiar las contraseñas dentro de MySQL (pide la contraseña de root **actual**):
   ```bash
   docker exec -it mysql mysql -u root -p
   ```
   ```sql
   ALTER USER 'nuxbill'@'%' IDENTIFIED BY 'NUEVA-CLAVE-APP-AQUI';
   ALTER USER 'root'@'%' IDENTIFIED BY 'NUEVA-CLAVE-ROOT-AQUI';
   ALTER USER 'root'@'localhost' IDENTIFIED BY 'NUEVA-CLAVE-ROOT-AQUI';
   EXIT;
   ```
   (Si `MYSQL_USER` no es `nuxbill`, usar ese nombre.)
3. Actualizar `config.php`. **Primero parar el contenedor**: mientras corre,
   `config-sync.sh` pisa `./data/config.php` con la copia vieja de adentro.
   ```bash
   docker compose stop nuxbill
   ```
   Editar `./data/config.php` en el host y poner la nueva clave en `$db_pass`
   (y en `$radius_pass`, si existe).
4. Poner las mismas claves nuevas en `.env` (`MYSQL_PASSWORD` y
   `MYSQL_ROOT_PASSWORD`).
5. Levantar todo de nuevo. Al arrancar, `entrypoint.sh` copia
   `./data/config.php` adentro del contenedor:
   ```bash
   docker compose up -d
   ```
6. Entrar al admin y comprobar que todo carga. Si da error de base de datos,
   revisar que la clave de `./data/config.php` sea la misma que la del paso 2.

---

## Notas de revisión

Cosas del proyecto que contradicen la guía original o que conviene revisar:

1. **`.env` dentro de la imagen y accesible por web** (corregido en el repo el
   2026-10-23, falta reconstruir en el servidor y cambiar las contraseñas).
   `.dockerignore` no excluía `.env` ni `data/`, el `Dockerfile` hace
   `COPY . /var/www/html`, y la config de Apache de la imagen solo bloqueaba
   archivos `.ht*`, así que `/.env` se servía tal cual.
2. **El instalador seguía accesible** (corregido en el repo el 2026-10-23, falta
   reconstruir en el servidor). `install/` no tiene protección para cuando
   PHPNuxBill ya está instalado (solo `init.php` redirige a `/install` si falta
   `config.php`, no al revés). El propio actualizador de PHPNuxBill
   (`update.php`) borra `install/`, así que bloquearla no rompe nada.
3. **FreeRADIUS sigue en el compose** aunque se eligió API. Si se conserva para
   el futuro, tiene dos fallas conocidas:
   - `freeradius/entrypoint.sh` agrega el bloque `client mikrotik` a
     `clients.conf` en cada arranque. Con `docker restart` (o el reinicio
     automático) queda duplicado y FreeRADIUS puede no arrancar.
   - `freeradius/sql.conf.template` no tiene `read_clients = yes`, así que los
     NAS cargados en **Radius → Radius NAS** no se usan.
4. **El theme del cliente no se versiona.** `.gitignore` ignora `ui/ui_custom/**`
   (heredado del repo original). Para el objetivo de "clonar y levantar en
   cualquier servidor" hay que sacar esa regla o versionar el theme aparte.
5. **Zona horaria por defecto incorrecta.** `.env.example` trae
   `TZ=Africa/Nairobi` (heredado del repo original).
6. **`pull_policy: always` en `nuxbill`**, un servicio que se construye localmente
   (`build: ./`). Viene del compose de ejemplo oficial y no aporta nada: la
   imagen base se actualiza con `docker compose build --pull`. Conviene
   quitarlo para evitar intentos de descarga de una imagen que no existe en
   Docker Hub.
7. **`api-ssl` no sirve con PHPNuxBill.** Su cliente RouterOS
   (`system/devices/MikrotikHotspot.php` → `getClient()`) no abre conexiones TLS,
   así que la API va siempre por `8728` y solo por LAN o túnel.
8. **La URL del túnel de Cloudflare** depende de dónde corra `cloudflared`:
   `http://localhost:80` si está en el host, `http://nuxbill:80` si está como
   contenedor del compose.
9. **La guía exportada del chat web no llegó** con el pedido (el prompt traía
   el texto de relleno en lugar del documento). Este archivo se armó a partir
   del repo y de la documentación ya existente (README, `CUSTOMIZATION.md`,
   `CLAUDE.md`). Si esa guía tenía algo más (por ejemplo, pasos ya hechos en el
   servidor), hay que sumarlo.
