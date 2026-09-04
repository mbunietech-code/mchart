<?php

namespace App\Services\Push;

use App\Contracts\PushNotificationSender;
use App\Models\Notification;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Firebase Cloud Messaging HTTP v1 sender.
 *
 * Requires a service-account JSON key (Firebase console → Project settings →
 * Service accounts) at the path given by config('services.fcm.credentials').
 * Enable it with PUSH_DRIVER=fcm.
 */
class FcmPushSender implements PushNotificationSender
{
    private const SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';

    public function send(Notification $notification): void
    {
        $credentials = $this->credentials();

        if ($credentials === null) {
            Log::warning('[fcm] credentials missing; skipping push', ['notification_id' => $notification->id]);

            return;
        }

        $tokens = $notification->user()->first()?->devices()->pluck('push_token')->all() ?? [];

        if ($tokens === []) {
            return;
        }

        $accessToken = $this->accessToken($credentials);
        $projectId = $credentials['project_id'];

        foreach ($tokens as $token) {
            $response = Http::withToken($accessToken)
                ->post("https://fcm.googleapis.com/v1/projects/{$projectId}/messages:send", [
                    'message' => [
                        'token' => $token,
                        'notification' => [
                            'title' => $notification->title,
                            'body' => $notification->body,
                        ],
                        'data' => array_map('strval', [
                            'type' => $notification->type,
                            'reference_type' => (string) $notification->reference_type,
                            'reference_id' => (string) $notification->reference_id,
                        ]),
                    ],
                ]);

            if ($response->failed()) {
                Log::warning('[fcm] send failed', [
                    'status' => $response->status(),
                    'body' => $response->json(),
                ]);
            }
        }
    }

    /**
     * @return array<string, string>|null
     */
    private function credentials(): ?array
    {
        $path = config('services.fcm.credentials');

        if (! $path || ! is_file($path)) {
            return null;
        }

        return json_decode((string) file_get_contents($path), true);
    }

    /**
     * Exchange the service-account key for a short-lived OAuth2 access token.
     *
     * @param  array<string, string>  $credentials
     */
    private function accessToken(array $credentials): string
    {
        return Cache::remember('fcm.access_token', now()->addMinutes(50), function () use ($credentials) {
            $now = time();

            $jwt = $this->encodeJwt([
                'iss' => $credentials['client_email'],
                'scope' => self::SCOPE,
                'aud' => 'https://oauth2.googleapis.com/token',
                'iat' => $now,
                'exp' => $now + 3600,
            ], $credentials['private_key']);

            $response = Http::asForm()->post('https://oauth2.googleapis.com/token', [
                'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                'assertion' => $jwt,
            ])->throw();

            return $response->json('access_token');
        });
    }

    /**
     * @param  array<string, mixed>  $claims
     */
    private function encodeJwt(array $claims, string $privateKey): string
    {
        $encode = static fn (array $part): string => rtrim(strtr(base64_encode(json_encode($part)), '+/', '-_'), '=');

        $segments = [
            $encode(['alg' => 'RS256', 'typ' => 'JWT']),
            $encode($claims),
        ];

        openssl_sign(implode('.', $segments), $signature, $privateKey, OPENSSL_ALGO_SHA256);
        $segments[] = rtrim(strtr(base64_encode($signature), '+/', '-_'), '=');

        return implode('.', $segments);
    }
}
