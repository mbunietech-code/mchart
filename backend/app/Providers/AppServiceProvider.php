<?php

namespace App\Providers;

use App\Contracts\PushNotificationSender;
use App\Services\Push\FcmPushSender;
use App\Services\Push\LogPushSender;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->bind(PushNotificationSender::class, function ($app) {
            return match (config('services.push.driver')) {
                'fcm' => $app->make(FcmPushSender::class),
                default => $app->make(LogPushSender::class),
            };
        });
    }

    public function boot(): void
    {
        //
    }
}
