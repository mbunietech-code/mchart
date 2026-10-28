<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\User */
class UserResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'email' => $this->email,
            'phone' => $this->phone,
            'avatar_url' => $this->avatar_path ? \App\Services\AttachmentStorage::url($this->avatar_path) : null,
            'role' => $this->roleEnum()?->value,
            // Job title (custom roles), falling back to the level's name.
            'role_label' => $this->role?->label ?: $this->roleEnum()?->label(),
            'role_id' => $this->role_id,
            'status' => $this->status,
            'department_id' => $this->department_id,
            'department' => new DepartmentResource($this->whenLoaded('department')),
            'last_seen_at' => $this->last_seen_at,
            'must_change_password' => (bool) $this->must_change_password,
            'created_at' => $this->created_at,
        ];
    }
}
