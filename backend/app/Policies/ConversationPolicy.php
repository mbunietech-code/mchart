<?php

namespace App\Policies;

use App\Enums\ConversationType;
use App\Models\Conversation;
use App\Models\Message;
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
        return $conversation->isManagedBy($user);
    }

    /** Add/remove participants, i.e. group admin controls. */
    public function manageParticipants(User $user, Conversation $conversation): bool
    {
        return $conversation->isManagedBy($user);
    }

    /** A member can always leave a group themselves. */
    public function leave(User $user, Conversation $conversation): bool
    {
        return $conversation->hasParticipant($user);
    }

    public function deleteMessage(User $user, Conversation $conversation, Message $message): bool
    {
        return $user->isAdmin()
            || $message->sender_id === $user->id
            || $conversation->isManagedBy($user);
    }
}
