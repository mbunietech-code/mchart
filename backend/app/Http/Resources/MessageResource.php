<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\Message */
class MessageResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $deleted = $this->isDeleted();

        return [
            'id' => $this->id,
            'conversation_id' => $this->conversation_id,
            'sender_id' => $this->sender_id,
            'sender' => new UserResource($this->whenLoaded('sender')),
            'body' => $deleted ? null : $this->body,
            'type' => $this->type->value,
            'read_by' => $this->read_by ?? [],
            'deleted' => $deleted,
            'attachments' => $deleted
                ? []
                : MessageAttachmentResource::collection($this->whenLoaded('attachments')),
            'reply_to' => $this->whenLoaded(
                'replyTo',
                fn () => $this->replyTo ? [
                    'id' => $this->replyTo->id,
                    'sender_name' => $this->replyTo->sender?->name,
                    'body' => $this->replyTo->isDeleted() ? null : $this->replyTo->body,
                    'deleted' => $this->replyTo->isDeleted(),
                ] : null,
            ),
            'reactions' => $this->whenLoaded('reactions', function () use ($request) {
                $grouped = $this->reactions->groupBy('emoji');

                return $grouped->map(fn ($group, $emoji) => [
                    'emoji' => $emoji,
                    'count' => $group->count(),
                    'mine' => $group->contains('user_id', $request->user()?->id),
                ])->values();
            }),
            'created_at' => $this->created_at,
        ];
    }
}
