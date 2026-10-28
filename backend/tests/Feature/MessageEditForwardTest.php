<?php

namespace Tests\Feature;

use App\Models\Conversation;
use App\Models\Department;
use App\Models\Message;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\Concerns\CreatesOrgUsers;
use Tests\TestCase;

class MessageEditForwardTest extends TestCase
{
    use CreatesOrgUsers, RefreshDatabase;

    public function test_sender_can_edit_own_text_message_within_window(): void
    {
        $dept = Department::factory()->create();
        [$a, $b] = [$this->staff($dept), $this->staff($dept)];
        $c = Conversation::factory()->direct()->withParticipants([$a, $b])->create();

        $id = $this->actingAs($a)->postJson("/api/v1/conversations/{$c->id}/messages", ['body' => 'Helo'])
            ->json('data.id');

        $this->actingAs($b)->patchJson("/api/v1/conversations/{$c->id}/messages/{$id}", ['body' => 'Hacked'])
            ->assertForbidden();

        $this->actingAs($a)->patchJson("/api/v1/conversations/{$c->id}/messages/{$id}", ['body' => 'Hello'])
            ->assertOk()
            ->assertJsonPath('data.body', 'Hello')
            ->assertJsonPath('data.edited_at', fn ($v) => $v !== null);

        Message::whereKey($id)->update(['created_at' => now()->subMinutes(16)]);
        $this->actingAs($a)->patchJson("/api/v1/conversations/{$c->id}/messages/{$id}", ['body' => 'Late'])
            ->assertStatus(422);
    }

    public function test_forward_copies_text_and_attachments_and_marks_forwarded(): void
    {
        Storage::fake(config('filesystems.default'));
        $dept = Department::factory()->create();
        [$a, $b, $c] = [$this->staff($dept), $this->staff($dept), $this->staff($dept)];
        $from = Conversation::factory()->direct()->withParticipants([$a, $b])->create();
        $to = Conversation::factory()->direct()->withParticipants([$a, $c])->create();

        $sourceId = $this->actingAs($b)->post("/api/v1/conversations/{$from->id}/messages", [
            'body' => 'Report attached',
            'attachments' => [UploadedFile::fake()->create('report.pdf', 20, 'application/pdf')],
        ], ['Accept' => 'application/json'])->assertCreated()->json('data.id');

        $res = $this->actingAs($a)->postJson("/api/v1/conversations/{$to->id}/messages", [
            'forward_message_id' => $sourceId,
        ])->assertCreated()
            ->assertJsonPath('data.forwarded', true)
            ->assertJsonPath('data.body', 'Report attached')
            ->assertJsonCount(1, 'data.attachments');

        // The copy survives the original being deleted.
        $this->actingAs($b)->deleteJson("/api/v1/conversations/{$from->id}/messages/{$sourceId}")->assertOk();
        $copy = Message::with('attachments')->find($res->json('data.id'));
        Storage::disk(config('filesystems.default'))->assertExists($copy->attachments->first()->file_path);
    }

    public function test_cannot_forward_a_message_from_a_conversation_you_cannot_see(): void
    {
        $dept = Department::factory()->create();
        [$a, $b, $c] = [$this->staff($dept), $this->staff($dept), $this->staff($dept)];
        $private = Conversation::factory()->direct()->withParticipants([$b, $c])->create();
        $mine = Conversation::factory()->direct()->withParticipants([$a, $b])->create();
        $secret = $this->actingAs($b)->postJson("/api/v1/conversations/{$private->id}/messages", ['body' => 'secret'])
            ->json('data.id');

        $this->actingAs($a)->postJson("/api/v1/conversations/{$mine->id}/messages", ['forward_message_id' => $secret])
            ->assertForbidden();
    }

    public function test_sticker_message_accepts_pack_ids_only(): void
    {
        $dept = Department::factory()->create();
        [$a, $b] = [$this->staff($dept), $this->staff($dept)];
        $c = Conversation::factory()->direct()->withParticipants([$a, $b])->create();

        $this->actingAs($a)->postJson("/api/v1/conversations/{$c->id}/messages", ['type' => 'sticker', 'body' => 'thumbs_up'])
            ->assertCreated()->assertJsonPath('data.type', 'sticker');
        $this->actingAs($a)->postJson("/api/v1/conversations/{$c->id}/messages", ['type' => 'sticker', 'body' => '<script>'])
            ->assertUnprocessable();

        $this->assertDatabaseHas('notifications', ['user_id' => $b->id, 'body' => '[sticker]']);
    }
}
