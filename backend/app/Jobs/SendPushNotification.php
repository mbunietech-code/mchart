<?php

namespace App\Jobs;

use App\Contracts\PushNotificationSender;
use App\Models\Notification;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;

class SendPushNotification implements ShouldQueue
{
    use Queueable;

    public int $tries = 3;

    public int $backoff = 10;

    public function __construct(public Notification $notification)
    {
    }

    public function handle(PushNotificationSender $sender): void
    {
        $sender->send($this->notification);
    }
}
