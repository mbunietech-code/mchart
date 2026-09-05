<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\TaskStatus;
use App\Http\Controllers\Controller;
use App\Http\Requests\ReturnTaskRequest;
use App\Http\Resources\TaskResource;
use App\Models\Task;
use App\Services\TaskWorkflowService;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class TaskWorkflowController extends Controller
{
    public function __construct(private readonly TaskWorkflowService $workflow)
    {
    }

    public function start(Request $request, Task $task): TaskResource
    {
        $this->authorize('progress', $task);

        return $this->respond($this->workflow->start($task, $request->user()));
    }

    public function complete(Request $request, Task $task): TaskResource
    {
        $this->authorize('progress', $task);

        return $this->respond($this->workflow->complete($task, $request->user()));
    }

    public function approve(Request $request, Task $task): TaskResource
    {
        $this->authorize('review', $task);

        return $this->respond($this->workflow->approve($task, $request->user()));
    }

    public function return(ReturnTaskRequest $request, Task $task): TaskResource
    {
        $this->authorize('review', $task);

        return $this->respond(
            $this->workflow->returnForRevision($task, $request->user(), $request->string('note')->toString())
        );
    }

    /** Admin/manager/creator: force the task to any status, skipping the workflow rules. */
    public function setStatus(Request $request, Task $task): TaskResource
    {
        $this->authorize('review', $task);

        $data = $request->validate([
            'status' => ['required', Rule::enum(TaskStatus::class)],
        ]);

        return $this->respond(
            $this->workflow->override($task, TaskStatus::from($data['status']), $request->user())
        );
    }

    private function respond(Task $task): TaskResource
    {
        return new TaskResource($task->load([
            'creator', 'assignee', 'department', 'statusHistory.changedBy',
        ]));
    }
}
