<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\Announcement */
class AnnouncementResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $user = $request->user();

        return [
            'id' => $this->id,
            'category' => $this->category->value,
            'category_label' => $this->category->label(),
            'title' => $this->title,
            'body' => $this->body,
            'image_url' => $this->image_url,
            'pinned' => $this->pinned,
            'archived' => $this->isArchived(),
            'expires_at' => $this->expires_at,
            'department_id' => $this->department_id,
            'department' => new DepartmentResource($this->whenLoaded('department')),
            'author' => new UserResource($this->whenLoaded('author')),
            'is_read' => (bool) ($this->is_read ?? false) || ($user && $user->id === $this->author_id),
            // Read receipts are for whoever can manage the post.
            'read_count' => $this->when(
                $user && ($user->isAdmin() || $user->id === $this->author_id),
                fn () => (int) ($this->readers_count ?? 0),
            ),
            'can_manage' => $user ? $user->can('update', $this->resource) : false,
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
        ];
    }
}
