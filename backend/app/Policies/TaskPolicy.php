<?php

namespace App\Policies;

use App\Models\Task;
use App\Models\User;

class TaskPolicy
{
    public function viewAny(User $user): bool
    {
        return true;
    }

    public function view(User $user, Task $task): bool
    {
        if ($user->isAdmin()) {
            return true;
        }

        if ($user->isManager()) {
            return $task->department_id === $user->department_id
                || $task->created_by === $user->id
                || $task->assigned_to === $user->id;
        }

        return $task->assigned_to === $user->id;
    }

    public function create(User $user): bool
    {
        return $user->isManagerOrAdmin();
    }

    public function update(User $user, Task $task): bool
    {
        return $user->isAdmin() || $task->created_by === $user->id;
    }

    public function delete(User $user, Task $task): bool
    {
        return $user->isAdmin() || $task->created_by === $user->id;
    }

    /** Move to In Progress / mark Completed — assignee only. */
    public function progress(User $user, Task $task): bool
    {
        return $task->assigned_to === $user->id;
    }

    /** Approve or return for revision — creator, a manager in the task's department, or admin. */
    public function review(User $user, Task $task): bool
    {
        if ($user->isAdmin() || $task->created_by === $user->id) {
            return true;
        }

        return $user->isManager() && $task->department_id === $user->department_id;
    }

    public function comment(User $user, Task $task): bool
    {
        return $this->view($user, $task);
    }

    public function attach(User $user, Task $task): bool
    {
        return $this->view($user, $task);
    }
}
