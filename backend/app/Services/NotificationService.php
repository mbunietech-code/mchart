<?php

namespace App\Services;

use App\Events\NotificationCreated;
use App\Jobs\SendPushNotification;
use App\Models\Notification;
use App\Models\User;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Collection;

/**
 * Central notification pipeline (SDD §5.4).
 *
 * Every module (Chat, Tasks) calls this to: persist a notification row,
 * broadcast it over WebSocket to online clients, and queue a push for
 * offline/background devices.
 */
class NotificationService
{
    /**
     * @param  array<string, mixed>  $data
     */
    public function send(
        User $recipient,
        string $type,
        string $title,
        ?string $body = null,
        ?Model $reference = null,
        array $data = [],
    ): Notification {
        $notification = Notification::create([
            'user_id' => $recipient->id,
            'type' => $type,
            'title' => $title,
            'body' => $body,
            'reference_type' => $reference ? class_basename($reference) : null,
            'reference_id' => $reference?->getKey(),
            'data' => $data ?: null,
            'is_read' => false,
        ]);

        broadcast(new NotificationCreated($notification));
        SendPushNotification::dispatch($notification);

        return $notification;
    }

    /**
     * Fan a notification out to several recipients (e.g. every task watcher).
     *
     * @param  iterable<User>  $recipients
     * @param  array<string, mixed>  $data
     * @return Collection<int, Notification>
     */
    public function sendMany(
        iterable $recipients,
        string $type,
        string $title,
        ?string $body = null,
        ?Model $reference = null,
        array $data = [],
    ): Collection {
        $sent = collect();

        foreach ($recipients as $recipient) {
            $sent->push($this->send($recipient, $type, $title, $body, $reference, $data));
        }

        return $sent;
    }
}
