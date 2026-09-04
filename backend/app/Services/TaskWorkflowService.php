<?php

namespace App\Services;

use App\Enums\TaskStatus;
use App\Events\TaskStatusChanged;
use App\Models\Task;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Implements the task lifecycle (SDD §5.3):
 *   assigned → in_progress → completed → approved | revision → in_progress
 *
 * Every transition is validated, recorded in task_status_history, and fans
 * out notifications to the relevant people.
 */
class TaskWorkflowService
{
    public function __construct(private readonly NotificationService $notifications)
    {
    }

    public function start(Task $task, User $actor): Task
    {
        return $this->transition($task, TaskStatus::InProgress, $actor, function () use ($task) {
            $task->started_at ??= now();
        }, notify: fn () => $this->notifyCreator(
            $task,
            'task_started',
            "Task started: {$task->title}",
            "{$this->name($task->assignee)} started working on this task.",
        ));
    }

    public function complete(Task $task, User $actor): Task
    {
        return $this->transition($task, TaskStatus::Completed, $actor, function () use ($task) {
            $task->completed_at = now();
        }, notify: fn () => $this->notifyCreator(
            $task,
            'task_completed',
            "Task completed: {$task->title}",
            "{$this->name($task->assignee)} marked this task as completed and it is ready for review.",
        ));
    }

    public function approve(Task $task, User $actor): Task
    {
        return $this->transition($task, TaskStatus::Approved, $actor, function () use ($task) {
            $task->approved_at = now();
        }, notify: fn () => $this->notifyAssignee(
            $task,
            'task_approved',
            "Task approved: {$task->title}",
            "{$this->name($task->creator)} approved your work on this task.",
        ));
    }

    public function returnForRevision(Task $task, User $actor, string $note): Task
    {
        return $this->transition($task, TaskStatus::Revision, $actor, function () use ($task, $actor, $note) {
            $task->comments()->create([
                'user_id' => $actor->id,
                'comment' => $note,
                'is_revision_note' => true,
            ]);
        }, note: $note, notify: fn () => $this->notifyAssignee(
            $task,
            'task_revision',
            "Revision requested: {$task->title}",
            $note,
        ));
    }

    /**
     * @param  callable():void|null  $sideEffect
     * @param  callable():void|null  $notify
     */
    private function transition(
        Task $task,
        TaskStatus $target,
        User $actor,
        ?callable $sideEffect = null,
        ?string $note = null,
        ?callable $notify = null,
    ): Task {
        $from = $task->status;

        if (! $from->canTransitionTo($target)) {
            throw ValidationException::withMessages([
                'status' => "A task that is \"{$from->label()}\" cannot move to \"{$target->label()}\".",
            ]);
        }

        DB::transaction(function () use ($task, $from, $target, $actor, $sideEffect, $note) {
            $task->status = $target;
            $sideEffect && $sideEffect();
            $task->save();

            $task->statusHistory()->create([
                'old_status' => $from->value,
                'new_status' => $target->value,
                'changed_by' => $actor->id,
                'note' => $note,
                'changed_at' => now(),
            ]);
        });

        $task->refresh();

        event(new TaskStatusChanged($task, $from->value, $target->value));

        $notify && $notify();

        return $task;
    }

    private function notifyCreator(Task $task, string $type, string $title, string $body): void
    {
        if ($task->creator && $task->creator->isNot($task->assignee)) {
            $this->notifications->send($task->creator, $type, $title, $body, $task, [
                'task_id' => $task->id,
            ]);
        }
    }

    private function notifyAssignee(Task $task, string $type, string $title, string $body): void
    {
        if ($task->assignee && $task->assignee->isNot($task->creator)) {
            $this->notifications->send($task->assignee, $type, $title, $body, $task, [
                'task_id' => $task->id,
            ]);
        }
    }

    private function name(?User $user): string
    {
        return $user?->name ?? 'Someone';
    }
}
