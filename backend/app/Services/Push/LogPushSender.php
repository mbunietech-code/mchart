<?php

namespace App\Services\Push;

use App\Contracts\PushNotificationSender;
use App\Models\Notification;
use Illuminate\Support\Facades\Log;

/**
 * Default push sender for local/dev: writes the payload to the log instead of
 * contacting Firebase. Swap for {@see FcmPushSender} in production by setting
 * PUSH_DRIVER=fcm and providing FCM_CREDENTIALS_PATH.
 */
class LogPushSender implements PushNotificationSender
{
    public function send(Notification $notification): void
    {
        $tokens = $notification->user()->first()?->devices()->pluck('push_token')->all() ?? [];

        Log::channel('stack')->info('[push] '.$notification->title, [
            'user_id' => $notification->user_id,
            'type' => $notification->type,
            'body' => $notification->body,
            'reference' => [$notification->reference_type, $notification->reference_id],
            'devices' => count($tokens),
        ]);
    }
}
