<?php

namespace App\Services;

use App\Enums\TaskStatus;
use App\Models\Task;
use App\Models\TaskComment;
use App\Models\User;
use Illuminate\Database\Connection;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;

/**
 * Two-way sync between MChart tasks and mbuniehub.com/admin/tasks.
 *
 * Pull: hub rows changed since the last pull become (or update) MChart
 * tasks; comments follow. Push: Task / TaskComment model events write
 * MChart changes straight to the hub tables. People are matched by email;
 * a task whose assignee has no account on the other side is skipped.
 * Hub times are in its own timezone (config mchart.hub_timezone).
 */
class HubTaskSync
{
    /** True while applying hub rows, so the model events don't echo them back. */
    public static bool $pulling = false;

    private const STATUS_FROM_HUB = ['todo' => 'assigned', 'in_progress' => 'in_progress', 'done' => 'completed'];

    private const STATUS_TO_HUB = [
        'assigned' => 'todo', 'in_progress' => 'in_progress', 'revision' => 'in_progress',
        'completed' => 'done', 'approved' => 'done',
    ];

    private const PRIORITY_FROM_HUB = ['low' => 'low', 'normal' => 'medium', 'high' => 'high', 'urgent' => 'urgent'];

    private const PRIORITY_TO_HUB = ['low' => 'low', 'medium' => 'normal', 'high' => 'high', 'urgent' => 'urgent'];

    /** @var array<string, ?User> */
    private array $users = [];

    /** @var array<string, ?int> */
    private array $hubUsers = [];

    public function __construct(private readonly NotificationService $notifications)
    {
    }

    public static function enabled(): bool
    {
        return (bool) config('mchart.hub_sync');
    }

    /** Pull at most every 20 seconds; called by the task screens and the scheduler. */
    public function pullThrottled(): void
    {
        if (! self::enabled() || ! Cache::add('hub-sync:lock', 1, 20)) {
            return;
        }

        try {
            $this->pull();
        } catch (\Throwable $e) {
            report($e);
        }
    }

    public function pull(): void
    {
        self::$pulling = true;
        try {
            $this->pullTasks();
            $this->pullDeletions();
            $this->pullComments();
        } finally {
            self::$pulling = false;
        }
    }

    // ----- Hub -> MChart ---------------------------------------------------

    private function pullTasks(): void
    {
        $since = Cache::get('hub-sync:tasks-since', '1970-01-01 00:00:00');

        $rows = $this->hub()->table('admin_tasks as t')
            ->leftJoin('users as a', 'a.id', '=', 't.assigned_to')
            ->leftJoin('users as c', 'c.id', '=', 't.created_by')
            ->where('t.updated_at', '>=', $since)
            ->orderBy('t.updated_at')
            ->get(['t.*', 'a.email as assignee_email', 'c.email as creator_email', 'c.name as creator_name']);

        foreach ($rows as $row) {
            $this->applyHubTask($row);
            $since = (string) $row->updated_at;
        }

        Cache::forever('hub-sync:tasks-since', $since);
    }

    private function applyHubTask(object $row): void
    {
        $task = Task::where('hub_task_id', $row->id)->first();

        if ($row->status === 'cancelled') {
            $task?->delete();

            return;
        }

        $assignee = $this->user($row->assignee_email);
        if (! $assignee) {
            return; // Not on MChart (yet).
        }

        $attrs = [
            'title' => $row->title,
            'description' => $row->description,
            'priority' => self::PRIORITY_FROM_HUB[$row->priority] ?? 'medium',
            'deadline' => $row->due_at
                ? Carbon::parse($row->due_at, $this->hubTz())->endOfDay()->utc()
                : null,
            'assigned_to' => $assignee->id,
        ];

        if (! $task) {
            $creator = $this->user($row->creator_email) ?? $assignee;
            $status = self::STATUS_FROM_HUB[$row->status] ?? 'assigned';
            $task = (new Task)->forceFill($attrs + [
                'status' => $status,
                'created_by' => $creator->id,
                'department_id' => $assignee->department_id,
                'completed_at' => $status === 'completed' ? now() : null,
                'hub_task_id' => $row->id,
            ]);
            $task->save();
            $task->statusHistory()->create([
                'new_status' => $status,
                'changed_by' => $creator->id,
                'changed_at' => now(),
                'note' => 'From mbuniehub.com',
            ]);
            if ($creator->id !== $assignee->id && $status === 'assigned') {
                $this->notifications->send(
                    $assignee,
                    'task_assigned',
                    "New task: {$task->title}",
                    ($row->creator_name ?? 'mbuniehub').' assigned you a task.',
                    $task,
                    ['task_id' => $task->id],
                );
            }
            $this->importComments($task, $this->hubComments()->where('c.admin_task_id', $row->id)->get());

            return;
        }

        $task->fill($attrs);
        // Only move the status when the hub's bucket differs, so MChart-only
        // steps (approved, revision) survive a "done"/"in_progress" echo.
        $current = $task->status->value;
        if ((self::STATUS_TO_HUB[$current] ?? null) !== $row->status && isset(self::STATUS_FROM_HUB[$row->status])) {
            $new = self::STATUS_FROM_HUB[$row->status];
            $task->status = TaskStatus::from($new);
            $task->completed_at = $new === 'completed' ? now() : null;
            $task->statusHistory()->create([
                'old_status' => $current,
                'new_status' => $new,
                'changed_at' => now(),
                'note' => 'Changed on mbuniehub.com',
            ]);
        }
        if ($task->isDirty()) {
            $task->save();
        }
    }

    /** Hub tasks that were deleted there: remove their MChart copies. */
    private function pullDeletions(): void
    {
        Task::whereNotNull('hub_task_id')->select(['id', 'hub_task_id'])
            ->chunkById(500, function (Collection $tasks) {
                $alive = $this->hub()->table('admin_tasks')
                    ->whereIn('id', $tasks->pluck('hub_task_id'))
                    ->pluck('id')->all();
                $tasks->reject(fn (Task $t) => in_array($t->hub_task_id, $alive))
                    ->each(fn (Task $t) => $t->delete());
            });
    }

    private function pullComments(): void
    {
        $after = (int) Cache::get('hub-sync:comments-after', 0);
        $rows = $this->hubComments()->where('c.id', '>', $after)->orderBy('c.id')->get();

        $tasks = Task::whereIn('hub_task_id', $rows->pluck('admin_task_id')->unique())->get()->keyBy('hub_task_id');
        foreach ($rows->groupBy('admin_task_id') as $hubTaskId => $comments) {
            if ($task = $tasks->get($hubTaskId)) {
                $this->importComments($task, $comments);
            }
        }

        if ($rows->isNotEmpty()) {
            Cache::forever('hub-sync:comments-after', $rows->last()->id);
        }
    }

    private function importComments(Task $task, Collection $rows): void
    {
        foreach ($rows as $row) {
            if (TaskComment::where('hub_comment_id', $row->id)->exists()) {
                continue;
            }
            $user = $this->user($row->email);
            (new TaskComment)->forceFill([
                'task_id' => $task->id,
                'user_id' => $user?->id,
                'comment' => $user ? $row->body : '['.($row->name ?? 'mbuniehub').'] '.$row->body,
                'is_revision_note' => false,
                'hub_comment_id' => $row->id,
                'created_at' => Carbon::parse($row->created_at, $this->hubTz())->utc(),
            ])->save();
        }
    }

    // ----- MChart -> Hub ---------------------------------------------------

    public function pushTask(Task $task): void
    {
        if (! self::enabled() || self::$pulling) {
            return;
        }

        try {
            $assigneeId = $this->hubUserId($task->assignee?->email);
            if (! $assigneeId) {
                return; // The hub has no such person.
            }

            $now = now($this->hubTz())->toDateTimeString();
            $row = [
                'title' => $task->title,
                'description' => $task->description,
                'priority' => self::PRIORITY_TO_HUB[$task->priority->value] ?? 'normal',
                'status' => self::STATUS_TO_HUB[$task->status->value] ?? 'todo',
                'due_at' => $task->deadline?->copy()->tz($this->hubTz())->toDateString(),
                'assigned_to' => $assigneeId,
                'completed_at' => $task->completed_at?->copy()->tz($this->hubTz())->toDateTimeString(),
                'updated_at' => $now,
            ];

            if ($task->hub_task_id) {
                $this->hub()->table('admin_tasks')->where('id', $task->hub_task_id)->update($row);

                return;
            }

            $id = $this->hub()->table('admin_tasks')->insertGetId($row + [
                'created_by' => $this->hubUserId($task->creator?->email) ?? $assigneeId,
                'created_at' => $now,
            ]);
            $task->forceFill(['hub_task_id' => $id])->saveQuietly();
        } catch (\Throwable $e) {
            report($e);
        }
    }

    public function pushDelete(Task $task): void
    {
        if (! self::enabled() || self::$pulling || ! $task->hub_task_id) {
            return;
        }

        try {
            $this->hub()->table('admin_tasks')->where('id', $task->hub_task_id)->delete();
        } catch (\Throwable $e) {
            report($e);
        }
    }

    public function pushComment(TaskComment $comment): void
    {
        if (! self::enabled() || self::$pulling || $comment->hub_comment_id) {
            return;
        }

        try {
            $hubTaskId = $comment->task?->hub_task_id;
            if (! $hubTaskId) {
                return;
            }
            $now = now($this->hubTz())->toDateTimeString();
            $id = $this->hub()->table('admin_task_comments')->insertGetId([
                'admin_task_id' => $hubTaskId,
                'user_id' => $this->hubUserId($comment->user?->email),
                'body' => $comment->comment,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
            $comment->forceFill(['hub_comment_id' => $id])->saveQuietly();
        } catch (\Throwable $e) {
            report($e);
        }
    }

    // ----- Helpers ---------------------------------------------------------

    private function hub(): Connection
    {
        return DB::connection('hub');
    }

    private function hubTz(): string
    {
        return config('mchart.hub_timezone');
    }

    private function hubComments()
    {
        return $this->hub()->table('admin_task_comments as c')
            ->leftJoin('users as u', 'u.id', '=', 'c.user_id')
            ->select(['c.*', 'u.email', 'u.name']);
    }

    private function user(?string $email): ?User
    {
        if (! $email) {
            return null;
        }
        $key = strtolower($email);

        return $this->users[$key] ??= User::whereRaw('LOWER(email) = ?', [$key])->first();
    }

    private function hubUserId(?string $email): ?int
    {
        if (! $email) {
            return null;
        }
        $key = strtolower($email);

        return $this->hubUsers[$key] ??= $this->hub()->table('users')
            ->whereRaw('LOWER(email) = ?', [$key])->value('id');
    }
}
