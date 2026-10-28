<?php

namespace Tests\Feature;

use App\Models\Conversation;
use App\Models\Department;
use App\Models\Device;
use App\Services\Push\FcmPushSender;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Request as HttpRequest;
use Illuminate\Support\Facades\Http;
use Tests\Concerns\CreatesOrgUsers;
use Tests\TestCase;

class PushNotificationTest extends TestCase
{
    use CreatesOrgUsers, RefreshDatabase;

    private function useFakeFcm(array $sendResponse = [], int $status = 200): void
    {
        // Fake service account; a cached access token means no JWT is signed
        // and Google is never contacted.
        $path = storage_path('framework/testing/fcm-test.json');
        @mkdir(dirname($path), 0777, true);
        file_put_contents($path, json_encode([
            'type' => 'service_account',
            'project_id' => 'mchart-test',
            'client_email' => 'push@mchart-test.iam.gserviceaccount.com',
            'private_key' => 'unused',
        ]));

        config(['services.push.driver' => 'fcm', 'services.fcm.credentials' => $path]);
        $this->app->bind(\App\Contracts\PushNotificationSender::class, FcmPushSender::class);
        cache()->put('fcm.access_token', 'fake-token', 600);

        Http::fake([
            'oauth2.googleapis.com/*' => Http::response(['access_token' => 'fake-token']),
            'fcm.googleapis.com/*' => Http::response($sendResponse, $status),
        ]);
    }

    public function test_new_message_push_is_high_priority_with_chat_deep_link(): void
    {
        $this->useFakeFcm(['name' => 'projects/mchart-test/messages/1']);
        $dept = Department::factory()->create();
        [$a, $b] = [$this->staff($dept, ['name' => 'Amani']), $this->staff($dept)];
        $b->devices()->create(['platform' => 'android', 'push_token' => 'phone-b']);
        $c = Conversation::factory()->direct()->withParticipants([$a, $b])->create();

        $this->actingAs($a)->postJson("/api/v1/conversations/{$c->id}/messages", ['body' => 'Habari'])
            ->assertCreated();

        Http::assertSent(function (HttpRequest $r) use ($c) {
            if (! str_contains($r->url(), 'fcm.googleapis.com')) {
                return false;
            }
            $m = $r['message'];

            return $m['token'] === 'phone-b'
                && $m['notification']['title'] === 'Amani'
                && $m['notification']['body'] === 'Habari'
                && $m['android']['priority'] === 'high'
                && $m['android']['notification']['channel_id'] === 'mchart_messages'
                && $m['data']['conversation_id'] === (string) $c->id
                && $m['data']['type'] === 'new_message';
        });
    }

    public function test_unregistered_tokens_are_removed(): void
    {
        $this->useFakeFcm(['error' => ['status' => 'NOT_FOUND', 'details' => [['errorCode' => 'UNREGISTERED']]]], 404);
        $dept = Department::factory()->create();
        [$a, $b] = [$this->staff($dept), $this->staff($dept)];
        $b->devices()->create(['platform' => 'android', 'push_token' => 'stale']);
        $c = Conversation::factory()->direct()->withParticipants([$a, $b])->create();

        $this->actingAs($a)->postJson("/api/v1/conversations/{$c->id}/messages", ['body' => 'Hi'])->assertCreated();

        $this->assertDatabaseMissing('devices', ['push_token' => 'stale']);
    }

    public function test_a_phone_belongs_to_whoever_signed_in_last_and_logout_forgets_it(): void
    {
        $first = $this->staff();
        $second = $this->staff();

        $this->actingAs($first)->postJson('/api/v1/devices', ['platform' => 'android', 'push_token' => 'shared'])
            ->assertCreated();
        $this->actingAs($second)->postJson('/api/v1/devices', ['platform' => 'android', 'push_token' => 'shared'])
            ->assertCreated();

        $this->assertSame([$second->id], Device::where('push_token', 'shared')->pluck('user_id')->all());

        $token = $second->createToken('phone')->plainTextToken;
        $this->app['auth']->forgetGuards();
        $this->postJson('/api/v1/auth/logout', ['push_token' => 'shared'], ['Authorization' => "Bearer {$token}"])
            ->assertOk();
        $this->assertDatabaseMissing('devices', ['push_token' => 'shared']);
    }
}
