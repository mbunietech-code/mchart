# MChart API — v1 reference

Base URL: `http://localhost:8000/api/v1`
Auth: `Authorization: Bearer <token>` on every route except the three public
auth endpoints. Tokens are issued by `POST /auth/login` (Laravel Sanctum).

All list endpoints are paginated (`?page=`, `?per_page=`) and return the
standard Laravel `{ data, links, meta }` envelope. Single resources return
`{ data: {...} }`.

---

## Auth

| Method | Endpoint                  | Notes |
|--------|---------------------------|-------|
| POST   | `/auth/login`             | Body: `email`, `password`, `device_name?`. Returns `{ token, user }`. Throttled 6/min. |
| POST   | `/auth/logout`            | Revokes the current token. |
| POST   | `/auth/password/forgot`   | Body: `email`. Always 200 (no account enumeration). |
| POST   | `/auth/password/reset`    | Body: `token`, `email`, `password`, `password_confirmation`. |
| GET    | `/me`                     | Current user profile (with department + role). |

Inactive accounts cannot log in and existing tokens are rejected by the
`active` middleware.

## Devices (push registration)

| Method | Endpoint      | Notes |
|--------|---------------|-------|
| POST   | `/devices`    | Body: `platform` (`windows`\|`macos`\|`android`), `push_token`, `device_name?`. Idempotent on `push_token`. |
| DELETE | `/devices`    | Body: `push_token`. |

## Directory (all authenticated users)

| Method | Endpoint                 | Notes |
|--------|--------------------------|-------|
| GET    | `/users`                 | Filters: `department_id`, `role`, `status`, `search`. |
| GET    | `/users/{user}`          | |
| GET    | `/roles`                 | The three roles and their permission flags. |
| GET    | `/departments`           | With `users_count`. |
| GET    | `/departments/{id}`      | |

## Administration (`role:admin`)

| Method | Endpoint                 | Notes |
|--------|--------------------------|-------|
| POST   | `/users`                 | `name`, `email`, `password` (+`_confirmation`), `role`, `department_id?`, `phone?`. |
| PATCH  | `/users/{user}`          | Any subset. Setting `status=inactive` revokes tokens. |
| DELETE | `/users/{user}`          | Soft: deactivates + revokes tokens (history preserved). |
| POST   | `/departments`           | `name`, `description?`. |
| PATCH  | `/departments/{id}`      | |
| DELETE | `/departments/{id}`      | 422 if the department still has users. |

## Chat

| Method | Endpoint                                   | Notes |
|--------|--------------------------------------------|-------|
| GET    | `/conversations`                           | The caller's conversations, newest activity first, each with `unread_count` and `latest_message`. |
| POST   | `/conversations`                           | `type` (`direct`\|`group`\|`channel`), `name` (required unless direct), `participant_ids[]`, `department_id?`. A direct conversation between the same two people is reused. |
| GET    | `/conversations/{id}`                       | |
| GET    | `/conversations/{id}/messages`             | `?limit=` (default 30), `?before=<messageId>` for older pages. Ascending order. |
| POST   | `/conversations/{id}/messages`             | `body` and/or `attachments[]` (multipart, ≤20 MB each, ≤10). `type` auto-detected. `attachment_meta[i][duration_seconds]` for voice notes. |
| POST   | `/conversations/{id}/read`                 | Marks everything up to now as read for the caller. |

Real-time: subscribe to `private-conversation.{id}` for the `message.sent`
event.

## Tasks

| Method | Endpoint                        | Notes |
|--------|---------------------------------|-------|
| GET    | `/tasks`                        | Scoped by role (staff: own; manager: department + own; admin: all). Filters: `status`, `priority`, `assigned_to`, `department_id`, `overdue=1`, `search`. Sort: `sort=deadline\|priority\|status\|title\|created_at`, `direction=asc\|desc`. |
| POST   | `/tasks`                        | `role:manager\|admin`. `title`, `assigned_to`, `description?`, `priority?` (default `medium`), `deadline?`, `department_id?` (defaults to the assignee's). |
| GET    | `/tasks/{task}`                 | Full detail: attachments, comments, status history. |
| PATCH  | `/tasks/{task}`                 | Creator or admin. Edit title / description / priority / deadline / assignee. |
| DELETE | `/tasks/{task}`                 | Creator or admin. |

### Workflow transitions

| Method | Endpoint                   | Who        | Effect |
|--------|----------------------------|------------|--------|
| POST   | `/tasks/{task}/start`      | assignee   | `assigned`\|`revision` → `in_progress` |
| POST   | `/tasks/{task}/complete`   | assignee   | `in_progress` → `completed` (notifies creator) |
| POST   | `/tasks/{task}/approve`    | creator / dept manager / admin | `completed` → `approved` (notifies assignee) |
| POST   | `/tasks/{task}/return`     | creator / dept manager / admin | `completed` → `revision`. Body: `note` (required); saved as a revision comment + notified. |

Illegal transitions return `422` with a `status` error. Every transition is
written to `task_status_history`.

### Task comments & attachments

| Method | Endpoint                               | Notes |
|--------|----------------------------------------|-------|
| GET    | `/tasks/{task}/comments`               | |
| POST   | `/tasks/{task}/comments`               | `comment`. Notifies the other party. |
| POST   | `/tasks/{task}/attachments`            | multipart `file` (≤20 MB), `duration_seconds?`. |
| DELETE | `/tasks/{task}/attachments/{id}`       | Creator or admin. |

## Notifications

| Method | Endpoint                          | Notes |
|--------|-----------------------------------|-------|
| GET    | `/notifications`                  | `?unread=1` to filter. |
| GET    | `/notifications/unread-count`     | `{ unread: n }`. |
| POST   | `/notifications/{id}/read`        | |
| POST   | `/notifications/read-all`         | |
| DELETE | `/notifications/{id}`             | |

Real-time: subscribe to `private-user.{id}` for the `notification.created`
event.

## Dashboard

| Method | Endpoint                | Notes |
|--------|-------------------------|-------|
| GET    | `/dashboard/summary`    | `counts` (assigned / in_progress / completed / approved / revision / open / overdue), `completion_rate` (%), and `per_assignee` breakdown. Query: `from`, `to`, `department_id`, `assignee_id`. Scoped by role. |
| GET    | `/dashboard/activity`   | Recent task status-change feed. `?limit=` (default 40). |

## Real-time channels (SDD §6.6)

| Channel                       | Events |
|-------------------------------|--------|
| `private-user.{id}`           | `notification.created` |
| `private-conversation.{id}`   | `message.sent` (typing / read-receipts to follow) |
| `private-department.{id}`     | `task.status-changed` (managers & admins) |

Authorize via `POST /api/broadcasting/auth` with the bearer token.
Client env: `REVERB_APP_KEY`, `REVERB_HOST`, `REVERB_PORT`, `REVERB_SCHEME`.
