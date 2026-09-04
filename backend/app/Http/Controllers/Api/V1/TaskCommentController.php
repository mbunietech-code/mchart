<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreTaskCommentRequest;
use App\Http\Resources\TaskCommentResource;
use App\Models\Task;
use App\Services\NotificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class TaskCommentController extends Controller
{
    public function __construct(private readonly NotificationService $notifications)
    {
    }

    public function index(Task $task): AnonymousResourceCollection
    {
        $this->authorize('view', $task);

        return TaskCommentResource::collection(
            $task->comments()->with('user')->orderBy('id')->paginate(50)
        );
    }

    public function store(StoreTaskCommentRequest $request, Task $task): JsonResponse
    {
        $this->authorize('comment', $task);

        $comment = $task->comments()->create([
            'user_id' => $request->user()->id,
            'comment' => $request->string('comment')->toString(),
        ]);

        // Notify the other side of the task (creator ↔ assignee).
        $recipientId = $request->user()->id === $task->assigned_to
            ? $task->created_by
            : $task->assigned_to;

        if ($recipientId && $recipientId !== $request->user()->id) {
            $this->notifications->send(
                $task->assigned_to === $recipientId ? $task->assignee : $task->creator,
                'task_comment',
                "New comment on: {$task->title}",
                \Illuminate\Support\Str::limit($comment->comment, 120),
                $task,
                ['task_id' => $task->id],
            );
        }

        return (new TaskCommentResource($comment->load('user')))->response()->setStatusCode(201);
    }
}
