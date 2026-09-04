# Engineering notes — decisions & deviations from the SDD

These are the places where implementation reality differs from, or refines, the
Software Design Document. Keep this list current.

### Laravel 13, not 12
`composer create-project` installs the current stable line (13.x) and the
environment runs PHP 8.4. The SDD says Laravel 12 / PHP 8.2+. For a greenfield
build we track the current release; nothing in the design depends on a 12-only
API. Revisit only if a hosting constraint forces 8.2.

### MySQL storage engine forced to InnoDB
`config/database.php` sets `'engine' => env('DB_ENGINE', 'InnoDB')` because a
stock WAMP install ships `default_storage_engine=MyISAM`, which has a 1000-byte
index limit (breaks `varchar(255)` utf8mb4 unique keys) and no FK/transaction
support. This keeps the app correct without editing `my.ini`.

### `notifications` table is bespoke, not Laravel's
The SDD defines a custom `notifications` schema (`user_id`, `type`, `title`,
`body`, `reference_type`, `reference_id`, `is_read`). We follow it and model it
as `App\Models\Notification`. The `User` model therefore does **not** use the
`Illuminate\Notifications\Notifiable` trait — `$user->notifications()` is a plain
`hasMany`. If we later want Laravel's mail/broadcast notification channels, add
the trait under a different relation name.

### Push notifications are pluggable
`App\Contracts\PushNotificationSender` with two implementations:
- `LogPushSender` (default, `PUSH_DRIVER=log`) — writes the payload to the log.
- `FcmPushSender` (`PUSH_DRIVER=fcm`) — Firebase HTTP v1, signs its own JWT from
  a service-account key at `FCM_CREDENTIALS_PATH`. No extra Composer package.

Delivery always goes through the queued `SendPushNotification` job so API
responses never block on Firebase.

### Real-time
Laravel Reverb (`php artisan reverb:start`). Broadcasting auth is mounted at
`POST /api/broadcasting/auth` behind `auth:sanctum` (see `bootstrap/app.php`)
so token clients — not just cookie/SPA clients — can authorize private channels.

### Task workflow
`App\Services\TaskWorkflowService` is the only place task status changes. Legal
transitions live on the `TaskStatus` enum. Every transition writes
`task_status_history` and fans out notifications. Controllers just authorize and
delegate.

### Visibility
`Task::scopeVisibleTo(User)` + `TaskPolicy` implement role/department scoping in
one place; every task read path goes through it.

### Deferred to later increments
- Typing indicators & read receipts over WebSocket (schema supports them).
- Only pushing chat notifications to *offline* users (currently notifies all
  non-senders).
- Full-text search on messages/tasks (currently `LIKE`).
- Rate limiting tuning; message attachment virus scanning.
- Flutter client (`app/`).
