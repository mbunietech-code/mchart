<?php

namespace App\Providers;

use App\Contracts\PushNotificationSender;
use App\Services\Push\FcmPushSender;
use App\Services\Push\LogPushSender;
use Illuminate\Auth\Notifications\ResetPassword;
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
        // The reset email links to our own web page (there was no
        // 'password.reset' route, so sending the email used to fail).
        ResetPassword::createUrlUsing(
            fn ($user, string $token) => url('reset-password').'?'.http_build_query([
                'token' => $token,
                'email' => $user->getEmailForPasswordReset(),
            ]),
        );
    }
}
