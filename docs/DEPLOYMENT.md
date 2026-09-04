# Deploying the MChart backend (chart.mbuniehub.com)

Target: cPanel-style shared host with SSH access and the ability to run
persistent processes. Domain `chart.mbuniehub.com`, repo checked out at
`~/chart` (so the backend lives at `~/chart/backend`).

Replace `u125644160` with your actual cPanel user everywhere below.

---

## 1. Point the subdomain at Laravel's `public/`

cPanel → **Domains** (or **Subdomains**) → edit `chart.mbuniehub.com` →
set **Document Root** to:

```
/home/u125644160/chart/backend/public
```

Save. That is the only web-server change needed — `public/.htaccess` ships
with Laravel and does the rest.

---

## 2. PHP version

MChart runs on **Laravel 13 → PHP 8.3+** (8.4 is fine).
cPanel → **MultiPHP Manager** → set `chart.mbuniehub.com` to PHP 8.3 or 8.4.
Confirm over SSH:

```bash
cd ~/chart/backend && php -v
```

If the CLI `php` is an older version, use the versioned binary the host
provides (e.g. `ea-php83`, `/usr/local/bin/php83`) for every command below.

---

## 3. Install dependencies

```bash
cd ~/chart/backend
composer install --no-dev --optimize-autoloader --no-interaction
```

No Composer on PATH? `curl -sS https://getcomposer.org/installer | php` then
use `php composer.phar …`.

---

## 4. Environment file

```bash
cd ~/chart/backend
cp .env.production.example .env
```

Edit `.env` and fill:

- `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD` — from cPanel → **MySQL Databases**
  (the DB user must be **added to the database with ALL PRIVILEGES**).
- `REVERB_APP_KEY`, `REVERB_APP_SECRET` — long random strings, e.g.
  `php -r "echo bin2hex(random_bytes(24)).PHP_EOL;"` twice.

Then:

```bash
php artisan key:generate
php artisan migrate --force --seed
php artisan storage:link
```

`--seed` creates the roles, departments, an **admin** (`admin@mbunietech.com`
/ `password`) and a demo team. **Change the admin password immediately after
first login**, or drop the demo users.

---

## 5. Permissions

```bash
cd ~/chart/backend
chmod -R ug+rwX storage bootstrap/cache
```

---

## 6. Cache config for production

```bash
cd ~/chart/backend
php artisan config:cache
php artisan route:cache
php artisan event:cache
```

Re-run these after any `.env` or route change. To undo: `php artisan optimize:clear`.

---

## 7. Queue worker (notifications + push)

Keep one worker alive. With `systemd` unavailable on shared hosting, use a
**cron watchdog** — add in cPanel → **Cron Jobs** (every minute):

```
* * * * * cd /home/u125644160/chart/backend && (pgrep -f 'artisan queue:work' || nohup php artisan queue:work --sleep=3 --tries=3 --max-time=3600 >> storage/logs/queue.log 2>&1 &)
```

If the host has `supervisor` or Passenger, prefer that.

---

## 8. Real-time (Laravel Reverb)

### 8a. Run the Reverb process

Reverb binds locally on `127.0.0.1:8080` (set by `REVERB_SERVER_HOST` /
`REVERB_SERVER_PORT`). Cron watchdog, every minute:

```
* * * * * cd /home/u125644160/chart/backend && (pgrep -f 'artisan reverb:start' || nohup php artisan reverb:start >> storage/logs/reverb.log 2>&1 &)
```

### 8b. Proxy WebSockets through Apache

Reverb speaks the Pusher protocol on two path prefixes:
`/app` (client WebSocket) and `/apps` (server publish API). Both must reach
`127.0.0.1:8080`. Add to **`~/chart/backend/public/.htaccess`**, *above* the
`RewriteEngine On` Laravel block:

```apache
<IfModule mod_proxy.c>
    RewriteEngine On
    # WebSocket upgrade for the client channel
    RewriteCond %{HTTP:Upgrade} =websocket [NC]
    RewriteRule ^(app/.*)$ ws://127.0.0.1:8080/$1 [P,L]
    # Plain HTTP for the server publish API + health
    RewriteRule ^(apps/.*)$ http://127.0.0.1:8080/$1 [P,L]
</IfModule>
```

Requires `mod_proxy`, `mod_proxy_http`, `mod_proxy_wstunnel`, `mod_rewrite`
(standard on cPanel/EA4). If `[P]` is disabled for you, ask support to enable
`mod_proxy_wstunnel` for the domain, **or** switch to Pusher (see §8d).

### 8c. Verify

```bash
curl -s https://chart.mbuniehub.com/apps/mchart/health   # -> reverb "OK"/"healthy"
```

Then from the app, the top bar should read **Operational** (green).

### 8d. Fallback — Pusher instead of Reverb

If the proxy can't be enabled: create a free app at pusher.com, then in `.env`
set `BROADCAST_CONNECTION=pusher`, `PUSHER_APP_ID/KEY/SECRET/CLUSTER`, and
build the Flutter client with the matching `--dart-define`s. No Reverb
process or proxy needed.

---

## 9. Point the Flutter client at production

Build with:

```bash
cd app
flutter build windows --release \
  --dart-define=MCHART_API=https://chart.mbuniehub.com \
  --dart-define=MCHART_REVERB_HOST=chart.mbuniehub.com \
  --dart-define=MCHART_REVERB_PORT=443 \
  --dart-define=MCHART_REVERB_SCHEME=wss \
  --dart-define=MCHART_REVERB_KEY=<your REVERB_APP_KEY>
```

(`web`/`apk`/`macos` targets take the same defines.)

---

## 10. Redeploy after a `git pull`

```bash
cd ~/chart && git pull
cd backend
composer install --no-dev --optimize-autoloader
php artisan migrate --force
php artisan optimize:clear && php artisan config:cache && php artisan route:cache
pkill -f 'artisan queue:work'; pkill -f 'artisan reverb:start'   # watchdog cron restarts them
```

---

## Smoke test

```bash
curl -s https://chart.mbuniehub.com/up                       # 200
curl -s https://chart.mbuniehub.com/api/v1/me                 # 401 {"message":"Unauthenticated."}
curl -s -X POST https://chart.mbuniehub.com/api/v1/auth/login \
  -H 'Accept: application/json' -H 'Content-Type: application/json' \
  -d '{"email":"admin@mbunietech.com","password":"password"}'  # {"token":...,"user":...}
```
