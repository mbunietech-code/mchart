# Deploying the MChart backend

Reference deploy: **Hostinger shared hosting**, domain `chart.mbuniehub.com`,
repo at `~/domains/mbuniehub.com/public_html/chart` (so the backend is at
`.../chart/backend`). Replace `u125644160` with your hosting user.

Shared hosting caveats baked into this guide:
- `exec()` / `shell_exec()` are disabled → `storage:link` and `artisan tinker`
  don't work; use the workarounds below.
- Long-running processes are killed → **Laravel Reverb cannot run**; real-time
  needs Pusher (§8). Everything else works.
- MySQL has a low connection cap → cache/session use files, queue runs `sync`.

---

## 1. Subdomain → `backend/public`

hPanel → **Websites** → `mbuniehub.com` → **Subdomains**. Create `chart` and set
its **document root / custom folder** to:

```
public_html/chart/backend/public
```

Wait a few minutes for the auto-SSL certificate.

## 2. PHP 8.3+

hPanel → **Advanced → PHP Configuration** → set `chart.mbuniehub.com` to
PHP 8.3 or 8.4.

## 3. Code + dependencies

```bash
cd ~/domains/mbuniehub.com/public_html/chart
git pull                       # first time: git clone <repo> chart
cd backend
composer install --no-dev --optimize-autoloader --no-interaction
```

## 4. Environment

```bash
cp .env.production.example .env
php artisan key:generate
php -r '$e=file_get_contents(".env");
$e=preg_replace("/^REVERB_APP_KEY=.*/m","REVERB_APP_KEY=".bin2hex(random_bytes(20)),$e);
$e=preg_replace("/^REVERB_APP_SECRET=.*/m","REVERB_APP_SECRET=".bin2hex(random_bytes(20)),$e);
file_put_contents(".env",$e);'
```

Edit `.env` (`vi .env` — nano is not installed) and set **`DB_DATABASE`,
`DB_USERNAME`, `DB_PASSWORD`** from hPanel → **Databases → MySQL**. Keep
`DB_HOST=localhost` (the `@localhost` grant works; `127.0.0.1` is refused).

Verify the credentials directly before migrating:

```bash
mysql -u <DB_USERNAME> -p <DB_DATABASE> -e "SELECT 1;"
```

## 5. Migrate, seed, admin

```bash
php artisan config:clear
php artisan migrate --force --seed
php artisan mchart:admin you@mbuniehub.com --name="Your Name"   # prompts for a password
```

`--seed` also creates `admin@mbunietech.com` / `password` — **delete or repurpose
it**: `php artisan mchart:admin admin@mbunietech.com --password=<long-random>` or
just use your real admin from the command above.

## 6. Storage symlink (exec disabled → do it by hand)

```bash
ln -sfn "$(pwd)/storage/app/public" "$(pwd)/public/storage"
chmod -R ug+rwX storage bootstrap/cache
```

## 7. Cache for production

```bash
php artisan config:cache
php artisan route:cache
php artisan event:cache
```

Re-run all three after any `.env` or route change. Undo with
`php artisan optimize:clear`.

## 8. Real-time (Pusher — shared hosting)

Reverb needs a persistent process shared hosting won't allow. Use Pusher:

1. Create a free app at **pusher.com** → Channels.
2. In `.env`:
   ```
   BROADCAST_CONNECTION=pusher
   PUSHER_APP_ID=...
   PUSHER_APP_KEY=...
   PUSHER_APP_SECRET=...
   PUSHER_APP_CLUSTER=eu
   ```
3. `php artisan config:cache`
4. Build the Flutter client against Pusher (its key/cluster) instead of Reverb.

Until then `BROADCAST_CONNECTION=log` — notifications still persist and the
in-app notification list still works; only the live WebSocket push is inactive.

*(On a VPS/Cloud plan: keep `BROADCAST_CONNECTION=reverb`, run
`php artisan reverb:start` under a process manager, and proxy `/app` + `/apps`
to `127.0.0.1:8080` — see the `app/README.md` dart-defines and `config/reverb.php`.)*

## 9. Point the Flutter client at production

```bash
cd app
flutter build windows --release \
  --dart-define=MCHART_API=https://chart.mbuniehub.com
# add --dart-define=MCHART_REALTIME=off until Pusher/Reverb is live
```

Web / apk / macos take the same defines.

## 10. Redeploy after `git pull`

```bash
cd ~/domains/mbuniehub.com/public_html/chart && git pull
cd backend
composer install --no-dev --optimize-autoloader
php artisan migrate --force
php artisan optimize:clear
php artisan config:cache && php artisan route:cache && php artisan event:cache
```

---

## Smoke test

```bash
curl -s https://chart.mbuniehub.com/up                            # "Application up"
curl -s https://chart.mbuniehub.com/api/v1/me -H 'Accept: application/json'
#   -> {"message":"Unauthenticated."}
curl -s -X POST https://chart.mbuniehub.com/api/v1/auth/login \
  -H 'Accept: application/json' -H 'Content-Type: application/json' \
  -d '{"email":"you@mbuniehub.com","password":"..."}'
#   -> {"token":"...","user":{...}}
```

If a request 500s, set `APP_DEBUG=true`, `php artisan config:clear`, retry to
read the exception, then put `APP_DEBUG=false` back and re-cache.
Logs: `storage/logs/laravel-YYYY-MM-DD.log`.
