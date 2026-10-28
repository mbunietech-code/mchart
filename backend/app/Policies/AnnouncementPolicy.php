<?php

namespace App\Policies;

use App\Models\Announcement;
use App\Models\User;

class AnnouncementPolicy
{
    public function view(User $user, Announcement $announcement): bool
    {
        return $user->isAdmin()
            || $announcement->author_id === $user->id
            || $announcement->department_id === null
            || $announcement->department_id === $user->department_id;
    }

    /** Admins post to anyone; managers to their own department (checked in the request). */
    public function create(User $user): bool
    {
        return $user->isManagerOrAdmin();
    }

    /** Edit, pin, archive and delete. */
    public function update(User $user, Announcement $announcement): bool
    {
        return $user->isAdmin() || $announcement->author_id === $user->id;
    }

    public function delete(User $user, Announcement $announcement): bool
    {
        return $this->update($user, $announcement);
    }
}
