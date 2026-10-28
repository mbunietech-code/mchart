<?php

namespace App\Console\Commands;

use App\Enums\TaskStatus;
use App\Models\Task;
use App\Services\NotificationService;
use Illuminate\Console\Command;

/**
 * Hourly (routes/console.php): remind assignees of open tasks due within
 * the next 24 hours, once per task.
 */
class RemindTaskDeadlines extends Command
{
    protected $signature = 'tasks:remind-deadlines';

    protected $description = 'Notify assignees about open tasks due within 24 hours';

    public function handle(NotificationService $notifications): int
    {
        $tasks = Task::query()
            ->whereNull('deadline_reminded_at')
            ->whereNotNull('assigned_to')
            ->whereBetween('deadline', [now(), now()->addDay()])
            ->whereNotIn('status', [TaskStatus::Completed->value, TaskStatus::Approved->value])
            ->with('assignee')
            ->get();

        foreach ($tasks as $task) {
            if ($task->assignee) {
                $notifications->send(
                    $task->assignee,
                    'task_deadline',
                    'Deadline soon: '.$task->title,
                    'Due '.$task->deadline->diffForHumans().' ('.$task->deadline->format('D j M, H:i').').',
                    $task,
                    ['task_id' => $task->id],
                );
            }
            $task->forceFill(['deadline_reminded_at' => now()])->save();
        }

        $this->info("Reminded {$tasks->count()} task(s).");

        return self::SUCCESS;
    }
}
