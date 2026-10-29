<?php

namespace App\Models;

use App\Services\HubTaskSync;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable(['task_id', 'user_id', 'comment', 'is_revision_note'])]
class TaskComment extends Model
{
    protected static function booted(): void
    {
        static::created(fn (TaskComment $comment) => app(HubTaskSync::class)->pushComment($comment));
    }

    protected function casts(): array
    {
        return [
            'is_revision_note' => 'boolean',
        ];
    }

    public function task(): BelongsTo
    {
        return $this->belongsTo(Task::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
