<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\TaskPriority;
use App\Enums\TaskStatus;
use App\Http\Controllers\Controller;
use App\Http\Requests\StoreTaskRequest;
use App\Http\Requests\UpdateTaskRequest;
use App\Http\Resources\TaskResource;
use App\Models\Task;
use App\Services\NotificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class TaskController extends Controller
{
    public function __construct(private readonly NotificationService $notifications)
    {
    }

    public function index(Request $request): AnonymousResourceCollection
    {
        $this->authorize('viewAny', Task::class);

        $query = Task::query()
            ->visibleTo($request->user())
            ->with(['creator', 'assignee', 'department'])
            ->withCount(['comments', 'attachments']);

        if ($request->filled('status')) {
            $query->where('status', $request->string('status'));
        }

        if ($request->filled('priority')) {
            $query->where('priority', $request->string('priority'));
        }

        if ($request->filled('assigned_to')) {
            $query->where('assigned_to', $request->integer('assigned_to'));
        }

        if ($request->filled('department_id')) {
            $query->where('department_id', $request->integer('department_id'));
        }

        if ($request->boolean('overdue')) {
            $query->overdue();
        }

        if ($request->filled('search')) {
            $query->where('title', 'like', '%'.$request->string('search').'%');
        }

        $sort = $request->string('sort', 'created_at')->toString();
        $direction = $request->string('direction', 'desc')->toString();
        if (in_array($sort, ['created_at', 'deadline', 'priority', 'status', 'title'], true)) {
            $query->orderBy($sort, $direction === 'asc' ? 'asc' : 'desc');
        }

        return TaskResource::collection($query->paginate($request->integer('per_page', 20)));
    }

    public function store(StoreTaskRequest $request): JsonResponse
    {
        $data = $request->validated();
        $data['created_by'] = $request->user()->id;
        $data['priority'] ??= TaskPriority::Medium->value;
        $data['status'] = TaskStatus::Assigned->value;

        $task = Task::create($data);

        $task->statusHistory()->create([
            'old_status' => null,
            'new_status' => TaskStatus::Assigned->value,
            'changed_by' => $request->user()->id,
            'changed_at' => now(),
        ]);

        if ($task->assigned_to && $task->assigned_to !== $request->user()->id) {
            $this->notifications->send(
                $task->assignee,
                'task_assigned',
                "New task: {$task->title}",
                "{$request->user()->name} assigned you a task ({$task->priority->label()} priority).",
                $task,
                ['task_id' => $task->id],
            );
        }

        return (new TaskResource($task->load(['creator', 'assignee', 'department'])))
            ->response()
            ->setStatusCode(201);
    }

    public function show(Task $task): TaskResource
    {
        $this->authorize('view', $task);

        return new TaskResource($task->load([
            'creator', 'assignee', 'department',
            'attachments.uploader', 'comments.user', 'statusHistory.changedBy',
        ]));
    }

    public function update(UpdateTaskRequest $request, Task $task): TaskResource
    {
        $this->authorize('update', $task);

        $task->update($request->validated());

        return new TaskResource($task->load(['creator', 'assignee', 'department']));
    }

    public function destroy(Task $task): JsonResponse
    {
        $this->authorize('delete', $task);

        $task->delete();

        return response()->json(['message' => 'Task deleted.']);
    }
}
