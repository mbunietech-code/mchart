<?php

namespace App\Contracts;

use App\Models\Notification;

interface PushNotificationSender
{
    /**
     * Deliver a notification to all of the recipient's registered devices.
     */
    public function send(Notification $notification): void;
}
