# Guía de personalización de PHPNuxBill (este fork)

Esta guía junta lo que fuimos investigando sobre cómo extender y personalizar
este proyecto sin tocar el core de PHPNuxBill: cómo armar un gateway de pago
propio (con MercadoPago como caso concreto) y cómo editar la UI vía
`ui/ui_custom` sin que se pierda al actualizar.

## 1. Gateways de pago

### 1.1 Cómo está armado (no hay clase/interfaz, es por convención de nombres)

PHPNuxBill **no** usa un patrón de clase base / interfaz para gateways de
pago. Cada gateway es **un solo archivo PHP** en `system/paymentgateway/<id>.php`
(por ejemplo, `system/paymentgateway/mercadopago.php`), y el framework llama
a funciones sueltas con el prefijo del id (`mercadopago_...`) usando
`function_exists()` / `call_user_func()`. No hay manifest (`plugin.json`),
no hay build step, no hay proceso de "activación" más allá de un checkbox en
el admin.

Hoy `system/paymentgateway/` está vacía (solo un `index.html`) — los gateways
se instalan aparte vía el Plugin Manager, que simplemente copia archivos
`.php` sueltos a esa carpeta.

### 1.2 Funciones que hay que definir

| Función | Quién la llama (archivo) | Para qué |
|---|---|---|
| `mercadopago_validate_config()` | `system/controllers/order.php` | Chequea que ya cargaste las API keys antes de dejar comprar |
| `mercadopago_show_config()` | `system/controllers/paymentgateway.php` (GET) | Renderiza el formulario de configuración en el admin |
| `mercadopago_save_config()` | `system/controllers/paymentgateway.php` (POST) | Guarda las credenciales en `tbl_appconfig` |
| `mercadopago_create_transaction($trx, $user)` | `system/controllers/order.php`, al hacer "Comprar" | Llama a la API de MercadoPago, crea la preferencia/checkout, guarda la URL de pago en `$trx`, y redirige al cliente ahí |
| `mercadopago_get_status($trx, $user)` | `system/controllers/order.php`, botón "Check Payment" | Consulta el estado del pago; si está aprobado, acredita el servicio |
| `mercadopago_payment_notification()` | `system/controllers/callback.php` | El webhook/IPN — MercadoPago pega acá cuando cambia el estado de un pago |

### 1.3 Flujo completo (cliente → pago → servicio activado)

1. Cliente elige plan → elige gateway (dropdown alimentado por los gateways
   activados en Settings > Payment Gateway) → botón "Comprar"
   (`ui/ui/customer/selectGateway.tpl` → `order.php` caso `'buy'`).
2. `order.php` crea una fila en **`tbl_payment_gateway`** (`status = 1`,
   "no pagado": `gateway`, `plan_id`, `price`, `username`, etc.) y llama a
   `mercadopago_create_transaction($trx, $user)`.
3. Esa función pega contra la API de MercadoPago, guarda la URL de checkout
   en la misma fila (`pg_url_payment`, `gateway_trx_id`, `pg_request`), y
   redirige al cliente al checkout de MercadoPago (o lo deja como botón
   "Pay Now" en `ui/ui/customer/orderView.tpl`).
4. El cliente paga en MercadoPago y vuelve al sitio, o MercadoPago pega
   directo al webhook.
5. En `mercadopago_get_status()` (polling manual, botón "Check Payment") o
   `mercadopago_payment_notification()` (webhook), si el pago está
   aprobado:
   - Para compra de plan/servicio: `Package::rechargeUser($user['id'], $trx['routers'], $trx['plan_id'], $trx['gateway'], $canal)`
     (`system/autoload/Package.php`) — activa el servicio en el Mikrotik/RADIUS
     y genera el comprobante en **`tbl_transactions`**.
   - Para recarga de saldo: `Package::rechargeBalance(...)` /
     `Package::rechargeCustomBalance(...)` (mismo archivo).
   - Marcás la fila de `tbl_payment_gateway` como pagada: `status = 2`,
     `paid_date`, `pg_paid_response`, `payment_method`, `payment_channel`.

### 1.4 Tablas clave

- **`tbl_payment_gateway`** (schema en `install/phpnuxbill.sql`): la orden
  pendiente/completada — `gateway`, `gateway_trx_id`, `plan_id`, `price`,
  `pg_url_payment`, `pg_request`, `pg_paid_response`, `expired_date`,
  `paid_date`, `status` (`1` no pagado, `2` pagado, `3` fallido, `4` cancelado).
- **`tbl_transactions`**: el comprobante/ledger real, creado por
  `Package::rechargeUser` / `rechargeBalance` — `invoice`, `username`,
  `plan_name`, `price`, `expiration`, `method`, `type`
  (`Hotspot|PPPOE|Balance`).

### 1.5 El webhook

URL a registrar en MercadoPago: `https://tudominio/?_route=callback/mercadopago`.

`system/controllers/callback.php` (23 líneas) hace exactamente esto:
```php
$action = $routes['1'];
if (file_exists($PAYMENTGATEWAY_PATH . '/' . $action . '.php')) {
    include $PAYMENTGATEWAY_PATH . '/' . $action . '.php';
    if (function_exists($action . '_payment_notification')) {
        call_user_func($action . '_payment_notification');
        die();
    }
}
```
Adentro de `mercadopago_payment_notification()` leés el payload
(`php://input` / `$_POST`), validás la firma del webhook de MercadoPago,
buscás la fila de `tbl_payment_gateway` correspondiente (normalmente por
`gateway_trx_id` o un `external_reference` que vos mismo seteaste igual al
id de `$trx`), y hacés el mismo trabajo del punto 1.3.5.

### 1.6 Plantillas propias de configuración

Si tu `mercadopago_show_config()` necesita un `.tpl` propio (para el
formulario de API keys en el admin), va en `system/paymentgateway/ui/` — esa
carpeta está registrada como namespace `pg` en `system/boot.php`:
```php
$ui->addTemplateDir($PAYMENTGATEWAY_PATH . '/ui/', 'pg');
```
Se muestra con `$ui->display('pg-mercadopago.tpl')`.

### 1.7 Punto de partida real: gateways que existieron en este repo

PHPNuxBill traía bundleados 3 gateways (Xendit, Tripay, Duitku) que después
se sacaron del core (ver el link ["Payment Gateway List"](https://github.com/orgs/hotspotbilling/repositories?q=payment+gateway)
en el README). Siguen enteros en el historial de git de este mismo repo, en
el commit **`d5c3c237^`** (el padre del commit "payment gateway not
included"). Son el mejor template real para copiar — mismo patrón exacto,
solo cambia la API externa que llaman:

```bash
git show d5c3c237^:system/paymentgateway/xendit.php > /tmp/xendit-reference.php
git show d5c3c237^:system/paymentgateway/tripay.php > /tmp/tripay-reference.php
git show d5c3c237^:system/paymentgateway/duitku.php > /tmp/duitku-reference.php
```

Recomendación práctica para armar el de MercadoPago:

1. Copiá uno de esos tres como base (Tripay es el más simple de los tres).
2. Renombrá funciones/archivo a `mercadopago_*` / `mercadopago.php`.
3. Cambiá las llamadas HTTP a la API de MercadoPago (Preferencias / Checkout
   Pro para crear el pago, `/v1/payments/{id}` para consultar estado).
4. Sumá `mercadopago_payment_notification()` para el webhook (los tres
   ejemplos viejos no lo implementaban, confiaban solo en el polling manual
   — para MercadoPago sí conviene el webhook real).
5. No hace falta tocar nada más del core: en cuanto el archivo existe,
   aparece solo en la lista de gateways del admin (Settings > Payment
   Gateway) y, al activarlo, en el dropdown del cliente.

---

## 2. Personalizar la UI (`ui/ui_custom`)

### 2.1 Cómo funciona la resolución de templates

PHPNuxBill usa Smarty con **múltiples directorios de templates registrados
a la vez**, en este orden (`system/boot.php`):

```php
$ui->setTemplateDir([
    'custom' => 'ui/ui_custom/',      // se registra PRIMERO
    'theme'  => 'ui/themes/<tema>/',  // solo si hay un theme seleccionado
    'default'=> 'ui/ui/',             // el UI base de PHPNuxBill
]);
```

Cuando el código pide un template por su ruta relativa (por ejemplo,
`$ui->display('customer/login.tpl')`), Smarty busca ese mismo path relativo
en cada directorio registrado, **en el orden en que fueron agregados**, y usa
el primero que encuentra. Como `ui_custom` se registra primero, **cualquier
archivo que exista ahí gana**, sin importar si hay un theme seleccionado o
no — `ui_custom` pisa tanto al UI default como a cualquier theme.

### 2.2 Regla de oro: mismo path relativo

Para que tu edición pise el original, el archivo en `ui_custom` tiene que
estar en **exactamente la misma ruta relativa** que en `ui/ui/`. Ejemplos:

| Original (no tocar) | Tu copia editable |
|---|---|
| `ui/ui/customer/login.tpl` | `ui/ui_custom/customer/login.tpl` |
| `ui/ui/admin/header.tpl` | `ui/ui_custom/admin/header.tpl` |
| `ui/ui/widget/cron_monitor.tpl` | `ui/ui_custom/widget/cron_monitor.tpl` |

Si el archivo no existe en `ui_custom` con ese mismo path, Smarty sigue
usando el de `ui/ui/` normalmente — no rompe nada dejar `ui_custom` vacío o
con solo algunos archivos.

### 2.3 Flujo de trabajo recomendado

1. Ubicá el `.tpl` que querés cambiar dentro de `ui/ui/` (podés buscarlo por
   el texto que ves en pantalla, o mirando qué template llama el controller
   correspondiente en `system/controllers/`).
2. Copialo a `ui/ui_custom/` **respetando la misma subcarpeta**.
3. Editá la copia en `ui_custom` — nunca el original en `ui/ui/`.
4. Refrescá el navegador. Si no ves el cambio, revisá `ui/compiled/` — Smarty
   cachea templates compilados; en caso de dudas, se puede vaciar esa
   carpeta para forzar recompilación (cuidado si estás en Docker: esa carpeta
   vive dentro del contenedor, no en un volumen persistente).

### 2.4 Qué NO cubre `ui_custom`

`ui_custom` es un directorio de **templates Smarty** (`.tpl`), no un mirror
completo del sitio. Los assets estáticos (CSS, JS, imágenes) se sirven
directo por Apache desde su ruta real, normalmente vía la variable `{$_theme}`
que apunta a `ui/ui` o `ui/themes/<tema>` — **no** a `ui/ui_custom`. Si tu
`.tpl` en `ui_custom` necesita una imagen o CSS propio:

- Guardalo dentro de `ui/ui_custom/` igual (por ejemplo
  `ui/ui_custom/images/mi-logo.png`), y
- Referencialo en el `.tpl` con la ruta explícita, no con `{$_theme}`:
  ```smarty
  <img src="{$app_url}/ui/ui_custom/images/mi-logo.png">
  ```
  (`{$app_url}` sí está disponible en todos los templates).

### 2.5 Themes vs. `ui_custom` — no son lo mismo

- **`ui/themes/<nombre>/`**: un tema completo alternativo, seleccionable
  desde Settings > App (`$config['theme']`). Reemplaza el UI default entero.
- **`ui/ui_custom/`**: una capa de parches por-archivo que se aplica **sobre
  cualquier combinación** de default o theme activo. Para este proyecto (un
  branding puntual del cliente, no un tema completo alternativo),
  `ui_custom` es el mecanismo correcto — es liviano y sobrevive a los
  updates de PHPNuxBill sin necesitar mergear nada.

### 2.6 Por qué conviene este mecanismo en este proyecto Docker

Como el `Dockerfile` hace `COPY . /var/www/html` (ver `Dockerfile`), todo lo
que esté dentro de `ui/ui_custom/` en el repo viaja con la imagen
automáticamente en cada build — no hace falta ningún volumen ni paso extra
para que el theme del cliente esté presente en el server de producción.
