<?php

namespace App\Models;

use App\Enums\TaskPriority;
use App\Enums\TaskStatus;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

#[Fillable(['title', 'description', 'priority', 'status', 'deadline', 'created_by', 'assigned_to', 'department_id'])]
class Task extends Model
{
    use HasFactory;

    protected function casts(): array
    {
        return [
            'priority' => TaskPriority::class,
            'status' => TaskStatus::class,
            'deadline' => 'datetime',
            'started_at' => 'datetime',
            'completed_at' => 'datetime',
            'approved_at' => 'datetime',
        ];
    }

    protected $appends = ['is_overdue'];

    // ----- Relationships ---------------------------------------------------

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function assignee(): BelongsTo
    {
        return $this->belongsTo(User::class, 'assigned_to');
    }

    public function department(): BelongsTo
    {
        return $this->belongsTo(Department::class);
    }

    public function attachments(): HasMany
    {
        return $this->hasMany(TaskAttachment::class);
    }

    public function comments(): HasMany
    {
        return $this->hasMany(TaskComment::class);
    }

    public function statusHistory(): HasMany
    {
        return $this->hasMany(TaskStatusHistory::class)->orderBy('id');
    }

    // ----- Derived state -------------------------------------------------

    public function getIsOverdueAttribute(): bool
    {
        return $this->deadline !== null
            && $this->deadline->isPast()
            && ! in_array($this->status, [TaskStatus::Completed, TaskStatus::Approved], true);
    }

    // ----- Scopes -------------------------------------------------------

    public function scopeStatus(Builder $query, TaskStatus|string $status): Builder
    {
        return $query->where('status', $status instanceof TaskStatus ? $status->value : $status);
    }

    public function scopeForDepartment(Builder $query, ?int $departmentId): Builder
    {
        return $departmentId ? $query->where('department_id', $departmentId) : $query;
    }

    public function scopeOverdue(Builder $query): Builder
    {
        return $query->whereNotNull('deadline')
            ->where('deadline', '<', now())
            ->whereNotIn('status', [TaskStatus::Completed->value, TaskStatus::Approved->value]);
    }

    /**
     * Restrict the query to what the given user is allowed to see.
     */
    public function scopeVisibleTo(Builder $query, User $user): Builder
    {
        if ($user->isAdmin()) {
            return $query;
        }

        if ($user->isManager()) {
            return $query->where(function (Builder $q) use ($user) {
                $q->where('department_id', $user->department_id)
                    ->orWhere('created_by', $user->id)
                    ->orWhere('assigned_to', $user->id);
            });
        }

        return $query->where('assigned_to', $user->id);
    }
}
