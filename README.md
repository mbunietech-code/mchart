# MChart (Mbunie Chart)

A unified communication & task-management workspace for Mbunietech — chat, a
structured task lifecycle, real-time notifications, and management dashboards in
one product. Desktop-first (Windows / macOS), Android to follow.

See the source documents in the repo root:
`MChart_Concept_Note.docx`, `MChart_SRS.docx`, `MChart_SDD.docx`.

## Repository layout

| Path        | What it is                                              |
|-------------|--------------------------------------------------------|
| `backend/`  | Laravel 13 REST API + WebSocket broadcasting (MySQL)   |
| `app/`      | Flutter client (Windows / macOS / Android) — _to come_ |
| `docs/`     | API reference and engineering notes                    |

## Stack

- **Backend:** Laravel 13, PHP 8.4, MySQL 8, Laravel Sanctum (API tokens),
  Laravel Reverb (WebSockets), queued jobs for push.
- **Push:** pluggable — `log` driver by default, Firebase Cloud Messaging
  (`PUSH_DRIVER=fcm`) in production.
- **Client:** Flutter, single codebase across desktop and Android.

## Backend — quick start

```bash
cd backend
cp .env.example .env
composer install
php artisan key:generate
php artisan migrate --seed
php artisan serve            # http://localhost:8000
php artisan reverb:start     # WebSocket server on :8080
php artisan queue:work       # notification / push jobs
```

Requires a MySQL database named `mchart` (and `mchart_test` for the test suite).
The default engine is forced to InnoDB in `config/database.php`, so a server
configured with `default_storage_engine=MyISAM` (e.g. a stock WAMP install) still
works without editing `my.ini`.

### Seeded accounts (local only)

| Role    | Email                     | Password   |
|---------|---------------------------|------------|
| Admin   | admin@mbunietech.com      | `password` |
| Manager | manager@mbunietech.com    | `password` |
| Staff   | dev1@mbunietech.com …     | `password` |

### Tests

```bash
cd backend
php artisan test
```

The suite runs against the `mchart_test` MySQL database (see `phpunit.xml`).

## API

All endpoints live under `/api/v1` and use `Authorization: Bearer <token>`
(from `POST /api/v1/auth/login`). Full route list: `php artisan route:list`.
Reference: [`docs/API.md`](docs/API.md).
