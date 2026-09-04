<?php

namespace App\Events;

use App\Http\Resources\TaskResource;
use App\Models\Task;
use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class TaskStatusChanged implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public Task $task,
        public ?string $oldStatus,
        public string $newStatus,
    ) {
    }

    /**
     * @return array<int, Channel>
     */
    public function broadcastOn(): array
    {
        $channels = [];

        if ($this->task->assigned_to) {
            $channels[] = new PrivateChannel('user.'.$this->task->assigned_to);
        }

        if ($this->task->created_by) {
            $channels[] = new PrivateChannel('user.'.$this->task->created_by);
        }

        if ($this->task->department_id) {
            $channels[] = new PrivateChannel('department.'.$this->task->department_id);
        }

        return $channels;
    }

    public function broadcastAs(): string
    {
        return 'task.status-changed';
    }

    /**
     * @return array<string, mixed>
     */
    public function broadcastWith(): array
    {
        $this->task->loadMissing(['creator', 'assignee', 'department']);

        return [
            'old_status' => $this->oldStatus,
            'new_status' => $this->newStatus,
            'task' => (new TaskResource($this->task))->resolve(),
        ];
    }
}
