<?php

namespace Tests\Feature;

use App\Enums\ConversationType;
use App\Models\Conversation;
use App\Models\Department;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Concerns\CreatesOrgUsers;
use Tests\TestCase;

class ChatTest extends TestCase
{
    use CreatesOrgUsers, RefreshDatabase;

    public function test_user_can_start_a_direct_conversation_and_send_a_message(): void
    {
        $dept = Department::factory()->create();
        $a = $this->staff($dept);
        $b = $this->staff($dept);

        $conversation = $this->actingAs($a)->postJson('/api/v1/conversations', [
            'type' => ConversationType::Direct->value,
            'participant_ids' => [$b->id],
        ])->assertCreated()->json('data.id');

        $this->actingAs($a)->postJson("/api/v1/conversations/{$conversation}/messages", [
            'body' => 'Habari yako?',
        ])->assertCreated()->assertJsonPath('data.body', 'Habari yako?');

        $this->assertDatabaseHas('notifications', [
            'user_id' => $b->id,
            'type' => 'new_message',
        ]);
    }

    public function test_non_participant_cannot_read_a_conversation(): void
    {
        $dept = Department::factory()->create();
        $a = $this->staff($dept);
        $b = $this->staff($dept);
        $outsider = $this->staff($dept);

        $conversation = Conversation::factory()->direct()->withParticipants([$a, $b])->create();

        $this->actingAs($outsider)
            ->getJson("/api/v1/conversations/{$conversation->id}/messages")
            ->assertForbidden();
    }

    public function test_marking_a_conversation_read_clears_unread_count(): void
    {
        $dept = Department::factory()->create();
        $a = $this->staff($dept);
        $b = $this->staff($dept);
        $conversation = Conversation::factory()->direct()->withParticipants([$a, $b])->create();

        $this->actingAs($a)->postJson("/api/v1/conversations/{$conversation->id}/messages", ['body' => 'one']);
        $this->actingAs($a)->postJson("/api/v1/conversations/{$conversation->id}/messages", ['body' => 'two']);

        $this->actingAs($b)->getJson('/api/v1/conversations')
            ->assertOk()
            ->assertJsonPath('data.0.unread_count', 2);

        $this->actingAs($b)->postJson("/api/v1/conversations/{$conversation->id}/read")->assertOk();

        $this->actingAs($b)->getJson('/api/v1/conversations')
            ->assertJsonPath('data.0.unread_count', 0);
    }
}
