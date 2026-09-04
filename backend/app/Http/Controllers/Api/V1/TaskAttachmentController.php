<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\UploadAttachmentRequest;
use App\Http\Resources\TaskAttachmentResource;
use App\Models\Task;
use App\Models\TaskAttachment;
use App\Services\AttachmentStorage;
use Illuminate\Http\JsonResponse;

class TaskAttachmentController extends Controller
{
    public function __construct(private readonly AttachmentStorage $storage)
    {
    }

    public function store(UploadAttachmentRequest $request, Task $task): JsonResponse
    {
        $this->authorize('attach', $task);

        $meta = $this->storage->store($request->file('file'), "tasks/{$task->id}");

        $attachment = $task->attachments()->create([
            ...$meta,
            'duration_seconds' => $request->integer('duration_seconds') ?: null,
            'uploaded_by' => $request->user()->id,
        ]);

        return (new TaskAttachmentResource($attachment->load('uploader')))
            ->response()
            ->setStatusCode(201);
    }

    public function destroy(Task $task, TaskAttachment $attachment): JsonResponse
    {
        abort_unless($attachment->task_id === $task->id, 404);
        $this->authorize('update', $task);

        $this->storage->delete($attachment->file_path);
        $attachment->delete();

        return response()->json(['message' => 'Attachment removed.']);
    }
}
