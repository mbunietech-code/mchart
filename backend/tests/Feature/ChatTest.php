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

    public function test_marking_read_marks_the_other_participants_messages_as_read_by_me(): void
    {
        $dept = Department::factory()->create();
        $a = $this->staff($dept);
        $b = $this->staff($dept);
        $conversation = Conversation::factory()->direct()->withParticipants([$a, $b])->create();

        $messageId = $this->actingAs($a)
            ->postJson("/api/v1/conversations/{$conversation->id}/messages", ['body' => 'hi'])
            ->json('data.id');

        $this->actingAs($b)->postJson("/api/v1/conversations/{$conversation->id}/read")->assertOk();

        $this->actingAs($a)
            ->getJson("/api/v1/conversations/{$conversation->id}/messages")
            ->assertJsonFragment(['id' => $messageId, 'read_by' => [$a->id, $b->id]]);
    }

    public function test_user_can_reply_to_a_message(): void
    {
        $dept = Department::factory()->create();
        $a = $this->staff($dept);
        $b = $this->staff($dept);
        $conversation = Conversation::factory()->direct()->withParticipants([$a, $b])->create();

        $original = $this->actingAs($a)
            ->postJson("/api/v1/conversations/{$conversation->id}/messages", ['body' => 'original'])
            ->json('data.id');

        $this->actingAs($b)->postJson("/api/v1/conversations/{$conversation->id}/messages", [
            'body' => 'a reply',
            'reply_to_id' => $original,
        ])->assertCreated()
            ->assertJsonPath('data.reply_to.id', $original)
            ->assertJsonPath('data.reply_to.body', 'original');
    }

    public function test_user_can_react_and_unreact_to_a_message(): void
    {
        $dept = Department::factory()->create();
        $a = $this->staff($dept);
        $b = $this->staff($dept);
        $conversation = Conversation::factory()->direct()->withParticipants([$a, $b])->create();

        $messageId = $this->actingAs($a)
            ->postJson("/api/v1/conversations/{$conversation->id}/messages", ['body' => 'hi'])
            ->json('data.id');

        $this->actingAs($b)
            ->postJson("/api/v1/conversations/{$conversation->id}/messages/{$messageId}/reactions", ['emoji' => '👍'])
            ->assertOk()
            ->assertJsonFragment(['emoji' => '👍', 'count' => 1, 'mine' => true]);

        $this->actingAs($b)
            ->deleteJson("/api/v1/conversations/{$conversation->id}/messages/{$messageId}/reactions")
            ->assertOk()
            ->assertJsonPath('data.reactions', []);
    }

    public function test_sender_can_delete_their_own_message(): void
    {
        $dept = Department::factory()->create();
        $a = $this->staff($dept);
        $b = $this->staff($dept);
        $conversation = Conversation::factory()->direct()->withParticipants([$a, $b])->create();

        $messageId = $this->actingAs($a)
            ->postJson("/api/v1/conversations/{$conversation->id}/messages", ['body' => 'oops'])
            ->json('data.id');

        $this->actingAs($a)
            ->deleteJson("/api/v1/conversations/{$conversation->id}/messages/{$messageId}")
            ->assertOk();

        $this->actingAs($a)
            ->getJson("/api/v1/conversations/{$conversation->id}/messages")
            ->assertJsonFragment(['id' => $messageId, 'deleted' => true, 'body' => null]);
    }

    public function test_recipient_cannot_delete_someone_elses_message(): void
    {
        $dept = Department::factory()->create();
        $a = $this->staff($dept);
        $b = $this->staff($dept);
        $conversation = Conversation::factory()->direct()->withParticipants([$a, $b])->create();

        $messageId = $this->actingAs($a)
            ->postJson("/api/v1/conversations/{$conversation->id}/messages", ['body' => 'hi'])
            ->json('data.id');

        $this->actingAs($b)
            ->deleteJson("/api/v1/conversations/{$conversation->id}/messages/{$messageId}")
            ->assertForbidden();
    }

    public function test_group_admin_can_rename_add_and_remove_members(): void
    {
        $dept = Department::factory()->create();
        $creator = $this->staff($dept);
        $member = $this->staff($dept);
        $newcomer = $this->staff($dept);
        $conversation = Conversation::factory()->create(['created_by' => $creator->id]);
        $conversation->participants()->create(['user_id' => $creator->id, 'role' => 'admin', 'joined_at' => now()]);
        $conversation->participants()->create(['user_id' => $member->id, 'joined_at' => now()]);

        $this->actingAs($creator)
            ->patchJson("/api/v1/conversations/{$conversation->id}", ['name' => 'New Name'])
            ->assertOk()
            ->assertJsonPath('data.name', 'New Name');

        $this->actingAs($creator)
            ->postJson("/api/v1/conversations/{$conversation->id}/participants", ['user_ids' => [$newcomer->id]])
            ->assertOk();
        $this->assertDatabaseHas('conversation_participants', [
            'conversation_id' => $conversation->id,
            'user_id' => $newcomer->id,
        ]);

        $this->actingAs($creator)
            ->deleteJson("/api/v1/conversations/{$conversation->id}/participants/{$member->id}")
            ->assertOk();
        $this->assertDatabaseMissing('conversation_participants', [
            'conversation_id' => $conversation->id,
            'user_id' => $member->id,
        ]);
    }

    public function test_non_admin_member_cannot_rename_or_manage_a_group(): void
    {
        $dept = Department::factory()->create();
        $creator = $this->staff($dept);
        $member = $this->staff($dept);
        $conversation = Conversation::factory()->withParticipants([$creator, $member])->create([
            'created_by' => $creator->id,
        ]);

        $this->actingAs($member)
            ->patchJson("/api/v1/conversations/{$conversation->id}", ['name' => 'Hijacked'])
            ->assertForbidden();

        $this->actingAs($member)
            ->postJson("/api/v1/conversations/{$conversation->id}/participants", ['user_ids' => [$creator->id]])
            ->assertForbidden();
    }

    public function test_a_member_can_leave_a_group_on_their_own(): void
    {
        $dept = Department::factory()->create();
        $creator = $this->staff($dept);
        $member = $this->staff($dept);
        $conversation = Conversation::factory()->withParticipants([$creator, $member])->create([
            'created_by' => $creator->id,
        ]);

        $this->actingAs($member)
            ->deleteJson("/api/v1/conversations/{$conversation->id}/participants/{$member->id}")
            ->assertOk();

        $this->assertDatabaseMissing('conversation_participants', [
            'conversation_id' => $conversation->id,
            'user_id' => $member->id,
        ]);
    }
}
