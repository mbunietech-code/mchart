<?php

namespace App\Models;

use App\Enums\MessageType;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

#[Fillable(['conversation_id', 'sender_id', 'reply_to_id', 'body', 'type', 'read_by', 'deleted_at'])]
class Message extends Model
{
    use HasFactory;

    protected function casts(): array
    {
        return [
            'type' => MessageType::class,
            'read_by' => 'array',
            'deleted_at' => 'datetime',
        ];
    }

    public function conversation(): BelongsTo
    {
        return $this->belongsTo(Conversation::class);
    }

    public function sender(): BelongsTo
    {
        return $this->belongsTo(User::class, 'sender_id');
    }

    public function attachments(): HasMany
    {
        return $this->hasMany(MessageAttachment::class);
    }

    public function replyTo(): BelongsTo
    {
        return $this->belongsTo(Message::class, 'reply_to_id');
    }

    public function reactions(): HasMany
    {
        return $this->hasMany(MessageReaction::class);
    }

    public function isReadBy(int $userId): bool
    {
        return in_array($userId, $this->read_by ?? [], true);
    }

    public function isDeleted(): bool
    {
        return $this->deleted_at !== null;
    }
}
