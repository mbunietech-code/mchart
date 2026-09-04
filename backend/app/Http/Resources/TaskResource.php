<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\Task */
class TaskResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'title' => $this->title,
            'description' => $this->description,
            'priority' => $this->priority->value,
            'priority_label' => $this->priority->label(),
            'status' => $this->status->value,
            'status_label' => $this->status->label(),
            'deadline' => $this->deadline,
            'is_overdue' => $this->is_overdue,
            'department_id' => $this->department_id,
            'department' => new DepartmentResource($this->whenLoaded('department')),
            'creator' => new UserResource($this->whenLoaded('creator')),
            'assignee' => new UserResource($this->whenLoaded('assignee')),
            'started_at' => $this->started_at,
            'completed_at' => $this->completed_at,
            'approved_at' => $this->approved_at,
            'attachments' => TaskAttachmentResource::collection($this->whenLoaded('attachments')),
            'comments' => TaskCommentResource::collection($this->whenLoaded('comments')),
            'status_history' => TaskStatusHistoryResource::collection($this->whenLoaded('statusHistory')),
            'comments_count' => $this->whenCounted('comments'),
            'attachments_count' => $this->whenCounted('attachments'),
            'allowed_transitions' => collect($this->status->allowedTransitions())->map->value->all(),
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
        ];
    }
}
