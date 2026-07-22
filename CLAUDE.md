# Proyecto: PHPNuxBill empaquetado para cliente (Docker)

## Contexto
Cliente pidió integrar PHPNuxBill (software de billing para Mikrotik, hotspot/PPPOE)
en un servidor Linux propio. Requisito clave del cliente: dejar PHPNuxBill "limpio"
con su HTML/theme editado, y que **todo el paquete sea instalable fácilmente en
cualquier servidor** (no una instalación manual paso a paso).

## Decisión: Docker para producción
Se eligió Docker específicamente por el requisito de portabilidad/empaquetado del
cliente, no solo "porque sí". Objetivo: `docker compose up -d` en cualquier server
Linux y quedar andando, sin pasos manuales extra.

## Problema resuelto: cron dentro de la imagen (no en el host)
La imagen base de PHPNuxBill (`animegasan/phpnuxbill` o similar) **no trae cron
instalado**. PHPNuxBill necesita correr periódicamente:
- `system/cron.php` (tareas generales, ej. cada hora)
- `system/cron_reminder.php` (recordatorios, ej. una vez al día)

Como el objetivo es portabilidad total, **no** conviene depender del cron nativo
del host (eso obligaría a un paso manual en cada servidor nuevo). En cambio, hay
que armar un Dockerfile propio que:

1. Parta de la imagen base de PHPNuxBill.
2. Copie el theme/HTML del cliente ya editado (probablemente en `ui/ui_custom`
   o `ui/themes/<nombre>` — confirmar con el cliente, ver "Pendiente" abajo).
3. Instale `cron` en el build (`apt-get install -y cron`).
4. Copie un crontab predefinido con las dos tareas de arriba.
5. Use un entrypoint (idealmente con `supervisord`) que levante a la vez
   PHP-FPM/Nginx y el demonio `cron`, para que no haga falta arrancar nada
   a mano después del `docker compose up -d`.

Estructura de carpetas sugerida:
```
phpnuxbill-custom/
├── Dockerfile
├── docker-compose.yml
├── crontab
├── entrypoint.sh
└── theme/          # HTML/CSS editado del cliente
```

## Entorno local de desarrollo (aclaración importante)
Docker Desktop en Windows corre sobre WSL2 por debajo — no son alternativas
separadas. Para las pruebas locales (antes de tocar nada en el servidor del
cliente), se decidió ir con **WSL2 puro sin Docker** primero (LAMP nativo),
para entender la herramienta sin la capa extra de contenedores. Requiere activar
`systemd=true` en `/etc/wsl.conf` para que `cron` arranque como servicio normal.

Cuando se arme la imagen Docker definitiva, se puede probar esa misma imagen
también desde WSL2 (con Docker Desktop) para validar que se comporta igual
que en el servidor de producción.

## Pendiente / a confirmar con el cliente
Cuando el cliente dice que quiere "editar el HTML", falta confirmar si se refiere a:
- (a) Los temas/templates de PHPNuxBill (`ui/themes`, `ui/ui_custom`) — esto
  **sí** entra en la imagen Docker.
- (b) El **Login Template de Mikrotik** (la página de captive portal que ve el
  usuario al conectarse al wifi) — esto vive en el propio router Mikrotik como
  archivo aparte, **no** entra en la imagen Docker en absoluto.

## Punto de partida: Dockerfile y docker-compose oficiales del repo
El repo oficial (hotspotbilling/phpnuxbill) trae su propio `Dockerfile` y
`docker-compose.example.yml`. Se decidió usarlos como base (ya definen las
extensiones PHP correctas: gd, pdo_mysql, zip), pero **necesitan varios cambios**
antes de servir para el empaquetado final:

1. **Actualizar PHP**: el Dockerfile oficial usa `php:7.4-apache`, pero la
   documentación actual de PHPNuxBill pide mínimo PHP 8.2. Cambiar el `FROM`
   y revalidar que las extensiones compilen en esa versión.
2. **Faltan extensiones**: `mbstring` y `curl` no están instaladas en el
   Dockerfile oficial, pero la documentación las pide como requisito.
3. **Sin cron**: como en la imagen prearmada, hay que sumarlo con el enfoque
   de `supervisord` (ver sección de arriba).
4. **Sin theme ni entrypoint propio**: hay que copiar el theme del cliente y
   agregar el entrypoint que levante Apache/PHP-FPM + cron juntos.
5. **docker-compose.example.yml no persiste la base de datos**: el volumen de
   MySQL está comentado (`# skip data persistance (if dev testing)`). Para
   producción es obligatorio descomentarlo — si no, se pierde toda la base de
   clientes/facturación en cada reinicio del contenedor de MySQL.
6. **Puerto 3306 expuesto al host** (`3306:3306`) en el compose de ejemplo:
   para producción conviene sacar ese mapeo y dejar que la app se comunique
   con MySQL solo por la red interna de Docker Compose.

## Ubicación de este archivo y del proyecto
Este `CLAUDE.md` vive **dentro de la carpeta del repo de PHPNuxBill ya descargado**,
no en una carpeta vacía aparte. Es necesario partir del código fuente real
porque el Dockerfile oficial usa `COPY . /var/www/html`: ese `.` es el build
context (la carpeta donde se corre `docker build`), así que si no está el
código fuente ahí, la imagen se construye pero con `/var/www/html` vacío.
(La alternativa habría sido usar la imagen prearmada `animegasan/phpnuxbill`,
que ya trae el código horneado adentro — pero se decidió partir del Dockerfile
oficial del repo, así que esto aplica.)

Estructura de carpeta real:
```
phpnuxbill/                  ← carpeta del repo descargado
├── CLAUDE.md
├── Dockerfile                ← el oficial, a modificar (ver sección de arriba)
├── docker-compose.example.yml
├── system/
├── ui/
│   └── ui_custom/           ← acá va el theme editado del cliente
└── ... (resto del código fuente de PHPNuxBill)
```

Se recomendó además inicializar un repo Git en esta carpeta desde el arranque
para versionar los cambios propios (Dockerfile, theme, entrypoint) por separado
del código original del proyecto.

## Próximo paso
Tomar el Dockerfile y docker-compose oficiales como borrador de partida y
aplicarles los 6 cambios de arriba antes de darlos por buenos para el cliente.