# MChart client (Flutter)

Desktop-first (Windows / macOS) and Android client for the MChart workspace.
Talks to the Laravel API in [`../backend`](../backend).

## Run

```bash
cd app
flutter pub get
flutter run -d windows      # or: -d macos, -d <android-device>
```

Point it at a non-default API with dart-defines:

```bash
flutter run -d windows \
  --dart-define=MCHART_API=http://localhost:8000 \
  --dart-define=MCHART_REVERB_HOST=localhost \
  --dart-define=MCHART_REVERB_PORT=8080 \
  --dart-define=MCHART_REVERB_KEY=mchart-local-key
```

Defaults already target a local backend on `http://localhost:8000` with Reverb
on `ws://localhost:8080`. Start the backend, `php artisan reverb:start`, and
`php artisan queue:work` first.

Seeded demo logins (password `password`): `manager@mbunietech.com`,
`dev1@mbunietech.com`, `admin@mbunietech.com`.

## Architecture

| Layer | Choice |
|-------|--------|
| State | Riverpod 2 (`StateNotifier` + `FutureProvider`) |
| Routing | go_router with an auth-gated redirect + `ShellRoute` |
| HTTP | Dio, bearer token from `flutter_secure_storage` |
| Real-time | hand-rolled Pusher-protocol client over `web_socket_channel` (see `src/core/realtime.dart`) — `pusher_channels_flutter` has no desktop support |
| Models | plain immutable classes with `fromJson` (no codegen) |

```
lib/src/
  theme/        design system — AppColor (brand tokens), AppType (Inter), AppTheme
  core/         env, api client, token store, realtime, providers, formatting
  models/       User, Task, Conversation, Message, Notification, Dashboard, enums
  widgets/      AppCard, SectionCard, StatCard, StatusPill, AppAvatar, PageHeader…
  app/          MChartApp, router, AppShell (sidebar + top bar)
  features/
    auth/       login, AuthController
    chat/       list + thread panes, live message stream
    tasks/      board, detail (workflow bar + comments), task form
    dashboard/  summary cards, per-assignee completion, activity feed
    settings/   users table, departments, roles matrix, user form
    notifications/  bell dropdown panel + live stream
```

## Brand tokens (locked)

| Token | Value | Use |
|-------|-------|-----|
| Primary | `#1E40AF` | primary buttons, active nav, links, sent bubbles |
| Secondary | `#0F172A` | headers, dark surfaces, primary text |
| Accent | `#F59E0B` | priority/warning badges, unread counters |
| Neutral | `#64748B` | secondary text, borders, disabled |

All colours live in `lib/src/theme/app_color.dart`. Do not introduce new brand
colours — only the four tokens plus minimal functional status colours
(success green, danger red).

> `google_fonts` fetches Inter at first run and caches it. Bundle the font as an
> asset before shipping offline builds.
