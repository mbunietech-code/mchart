<?php

namespace App\Models;

use App\Enums\AnnouncementCategory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use App\Services\AttachmentStorage;

#[Fillable(['author_id', 'department_id', 'category', 'title', 'body', 'image_path', 'pinned', 'expires_at', 'archived_at'])]
class Announcement extends Model
{
    protected function casts(): array
    {
        return [
            'category' => AnnouncementCategory::class,
            'pinned' => 'boolean',
            'expires_at' => 'datetime',
            'archived_at' => 'datetime',
        ];
    }

    // ----- Relationships ---------------------------------------------------

    public function author(): BelongsTo
    {
        return $this->belongsTo(User::class, 'author_id');
    }

    public function department(): BelongsTo
    {
        return $this->belongsTo(Department::class);
    }

    public function readers(): BelongsToMany
    {
        return $this->belongsToMany(User::class, 'announcement_reads')->withPivot('read_at');
    }

    // ----- Helpers ---------------------------------------------------------

    public function getImageUrlAttribute(): ?string
    {
        return $this->image_path ? AttachmentStorage::url($this->image_path) : null;
    }

    public function isArchived(): bool
    {
        return $this->archived_at !== null || ($this->expires_at && $this->expires_at->isPast());
    }

    /** Everyone the announcement is addressed to, except its author. */
    public function audience(): Builder
    {
        return User::query()
            ->where('status', 'active')
            ->whereKeyNot($this->author_id)
            ->when($this->department_id, fn (Builder $q) => $q->where('department_id', $this->department_id));
    }

    // ----- Scopes ----------------------------------------------------------

    /** Company-wide posts, the user's department's posts, and their own. */
    public function scopeVisibleTo(Builder $query, User $user): Builder
    {
        if ($user->isAdmin()) {
            return $query;
        }

        return $query->where(function (Builder $q) use ($user) {
            $q->whereNull('department_id')
                ->orWhere('department_id', $user->department_id)
                ->orWhere('author_id', $user->id);
        });
    }

    /** Not archived by hand and not past its expiry. */
    public function scopeActive(Builder $query): Builder
    {
        return $query->whereNull('archived_at')
            ->where(fn (Builder $q) => $q->whereNull('expires_at')->orWhere('expires_at', '>', now()));
    }

    public function scopeArchived(Builder $query): Builder
    {
        return $query->where(fn (Builder $q) => $q->whereNotNull('archived_at')
            ->orWhere('expires_at', '<=', now()));
    }

    /** Authors never have their own posts outstanding. */
    public function scopeUnreadBy(Builder $query, User $user): Builder
    {
        return $query->where('author_id', '!=', $user->id)
            ->whereDoesntHave('readers', fn (Builder $q) => $q->whereKey($user->id));
    }
}
