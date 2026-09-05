<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\Conversation */
class ConversationResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'type' => $this->type->value,
            'name' => $this->name,
            'department_id' => $this->department_id,
            'created_by' => $this->created_by,
            'last_message_at' => $this->last_message_at,
            'participants' => $this->whenLoaded(
                'users',
                fn () => $this->users->map(fn ($u) => [
                    ...(new UserResource($u))->resolve($request),
                    'conversation_role' => $u->pivot->role,
                ]),
            ),
            'latest_message' => new MessageResource($this->whenLoaded('latestMessage', fn () => $this->latestMessage->first())),
            'unread_count' => $this->when(isset($this->unread_count), fn () => (int) $this->unread_count),
            'created_at' => $this->created_at,
        ];
    }
}
