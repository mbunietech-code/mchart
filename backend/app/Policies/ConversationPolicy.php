<?php

namespace App\Policies;

use App\Enums\ConversationType;
use App\Models\Conversation;
use App\Models\User;

class ConversationPolicy
{
    public function view(User $user, Conversation $conversation): bool
    {
        if ($user->isAdmin()) {
            return true;
        }

        if ($conversation->hasParticipant($user)) {
            return true;
        }

        // Department channels are visible to every member of that department.
        return $conversation->type === ConversationType::Channel
            && $conversation->department_id !== null
            && $conversation->department_id === $user->department_id;
    }

    public function sendMessage(User $user, Conversation $conversation): bool
    {
        return $conversation->hasParticipant($user);
    }

    public function update(User $user, Conversation $conversation): bool
    {
        if ($user->isAdmin() || $conversation->created_by === $user->id) {
            return true;
        }

        return $conversation->participants()
            ->where('user_id', $user->id)
            ->where('role', 'admin')
            ->exists();
    }
}
