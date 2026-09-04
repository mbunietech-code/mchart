<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\TaskStatusHistory */
class TaskStatusHistoryResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'old_status' => $this->old_status,
            'new_status' => $this->new_status,
            'note' => $this->note,
            'changed_by' => new UserResource($this->whenLoaded('changedBy')),
            'changed_at' => $this->changed_at,
        ];
    }
}
