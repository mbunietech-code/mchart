<?php

use App\Models\Conversation;
use App\Models\User;
use Illuminate\Support\Facades\Broadcast;

/*
| Real-time channel authorization (SDD §6.6).
*/

// Personal notification stream: task + message alerts.
Broadcast::channel('user.{id}', function (User $user, int $id) {
    return $user->id === $id;
});

// Per-conversation events: new message, typing, read receipts.
Broadcast::channel('conversation.{id}', function (User $user, int $id) {
    $conversation = Conversation::find($id);

    return $conversation !== null && $user->can('view', $conversation);
});

// Department-wide channel/task activity (managers & admins).
Broadcast::channel('department.{id}', function (User $user, int $id) {
    return $user->isAdmin() || ($user->isManagerOrAdmin() && $user->department_id === $id);
});
