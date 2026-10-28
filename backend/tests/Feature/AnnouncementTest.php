<?php

namespace Tests\Feature;

use App\Models\Announcement;
use App\Models\Department;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\Concerns\CreatesOrgUsers;
use Tests\TestCase;

class AnnouncementTest extends TestCase
{
    use CreatesOrgUsers, RefreshDatabase;

    private function payload(array $overrides = []): array
    {
        return array_merge([
            'category' => 'meeting',
            'title' => 'Company meeting',
            'body' => 'All team members must attend on Friday at 10:00 AM.',
        ], $overrides);
    }

    public function test_admin_posts_company_wide_and_everyone_is_notified(): void
    {
        $admin = $this->admin();
        $staffA = $this->staff();
        $staffB = $this->staff();

        $this->actingAs($admin)->postJson('/api/v1/announcements', $this->payload())
            ->assertCreated()
            ->assertJsonPath('data.category', 'meeting')
            ->assertJsonPath('data.department_id', null)
            ->assertJsonPath('data.can_manage', true);

        $this->actingAs($admin)->getJson('/api/v1/announcements/unread-count')->assertJson(['unread' => 0]);
        $this->actingAs($admin)->getJson('/api/v1/announcements')->assertJsonPath('data.0.is_read', true);

        foreach ([$staffA, $staffB] as $user) {
            $this->assertDatabaseHas('notifications', ['user_id' => $user->id, 'type' => 'announcement']);
            $this->actingAs($user)->getJson('/api/v1/announcements')
                ->assertOk()
                ->assertJsonCount(1, 'data')
                ->assertJsonPath('data.0.is_read', false)
                ->assertJsonPath('data.0.can_manage', false);
        }
        $this->assertDatabaseMissing('notifications', ['user_id' => $admin->id]);
    }

    public function test_staff_cannot_post(): void
    {
        $this->actingAs($this->staff())->postJson('/api/v1/announcements', $this->payload())
            ->assertForbidden();
    }

    public function test_manager_posts_only_to_own_department(): void
    {
        $deptA = Department::factory()->create();
        $deptB = Department::factory()->create();
        $manager = $this->manager($deptA);
        $inA = $this->staff($deptA);
        $inB = $this->staff($deptB);

        // No audience given: defaults to the manager's department.
        $this->actingAs($manager)->postJson('/api/v1/announcements', $this->payload())
            ->assertCreated()
            ->assertJsonPath('data.department_id', $deptA->id);

        $this->actingAs($manager)->postJson('/api/v1/announcements', $this->payload(['department_id' => $deptB->id]))
            ->assertUnprocessable()
            ->assertJsonValidationErrors('department_id');

        $this->actingAs($inA)->getJson('/api/v1/announcements')->assertJsonCount(1, 'data');
        $this->actingAs($inB)->getJson('/api/v1/announcements')->assertJsonCount(0, 'data');
        $this->assertDatabaseMissing('notifications', ['user_id' => $inB->id]);
    }

    public function test_department_post_is_hidden_from_other_departments(): void
    {
        $deptA = Department::factory()->create();
        $outsider = $this->staff(Department::factory()->create());
        $admin = $this->admin();

        $announcement = Announcement::create($this->payload([
            'author_id' => $admin->id,
            'department_id' => $deptA->id,
        ]));

        $this->actingAs($outsider)->getJson("/api/v1/announcements/{$announcement->id}")->assertForbidden();
        $this->actingAs($outsider)->postJson("/api/v1/announcements/{$announcement->id}/read")->assertForbidden();
    }

    public function test_read_marking_is_idempotent_and_updates_unread_count(): void
    {
        $admin = $this->admin();
        $staff = $this->staff();
        $announcement = Announcement::create($this->payload(['author_id' => $admin->id]));

        $this->actingAs($staff)->getJson('/api/v1/announcements/unread-count')->assertJson(['unread' => 1]);

        $this->actingAs($staff)->postJson("/api/v1/announcements/{$announcement->id}/read")->assertOk();
        $this->actingAs($staff)->postJson("/api/v1/announcements/{$announcement->id}/read")->assertOk();

        $this->assertDatabaseCount('announcement_reads', 1);
        $this->actingAs($staff)->getJson('/api/v1/announcements/unread-count')->assertJson(['unread' => 0]);
        $this->actingAs($admin)->getJson('/api/v1/announcements')->assertJsonPath('data.0.read_count', 1);
    }

    public function test_pinned_first_and_expired_or_archived_move_to_archive(): void
    {
        $admin = $this->admin();
        $old = Announcement::create($this->payload(['author_id' => $admin->id, 'title' => 'Old']));
        $pinned = Announcement::create($this->payload(['author_id' => $admin->id, 'title' => 'Pinned', 'pinned' => true]));
        $old->forceFill(['created_at' => now()->subDay()])->save();
        $pinned->forceFill(['created_at' => now()->subDays(2)])->save();
        Announcement::create($this->payload(['author_id' => $admin->id, 'title' => 'Expired', 'expires_at' => now()->subMinute()]));
        Announcement::create($this->payload(['author_id' => $admin->id, 'title' => 'Archived', 'archived_at' => now()]));

        $this->actingAs($admin)->getJson('/api/v1/announcements')
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('data.0.title', 'Pinned')
            ->assertJsonPath('data.1.title', 'Old');

        $this->actingAs($admin)->getJson('/api/v1/announcements?archived=1')
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('data.0.archived', true);
    }

    public function test_only_author_or_admin_can_edit_archive_or_delete(): void
    {
        $dept = Department::factory()->create();
        $author = $this->manager($dept);
        $otherManager = $this->manager($dept);
        $announcement = Announcement::create($this->payload(['author_id' => $author->id, 'department_id' => $dept->id]));

        $this->actingAs($otherManager)->patchJson("/api/v1/announcements/{$announcement->id}", ['pinned' => true])
            ->assertForbidden();

        $this->actingAs($author)->patchJson("/api/v1/announcements/{$announcement->id}", [
            'title' => 'Updated', 'pinned' => true, 'archived' => true,
        ])->assertOk()
            ->assertJsonPath('data.title', 'Updated')
            ->assertJsonPath('data.pinned', true)
            ->assertJsonPath('data.archived', true);

        $this->actingAs($this->admin())->deleteJson("/api/v1/announcements/{$announcement->id}")->assertOk();
        $this->assertDatabaseCount('announcements', 0);
    }

    public function test_search_and_category_filter(): void
    {
        $admin = $this->admin();
        Announcement::create($this->payload(['author_id' => $admin->id, 'category' => 'urgent', 'title' => 'Power outage']));
        Announcement::create($this->payload(['author_id' => $admin->id, 'category' => 'event', 'title' => 'Team lunch']));

        $this->actingAs($admin)->getJson('/api/v1/announcements?category=urgent')
            ->assertJsonCount(1, 'data')->assertJsonPath('data.0.title', 'Power outage');
        $this->actingAs($admin)->getJson('/api/v1/announcements?search=lunch')
            ->assertJsonCount(1, 'data')->assertJsonPath('data.0.title', 'Team lunch');
    }

    public function test_image_is_validated_and_stored(): void
    {
        Storage::fake(config('filesystems.default'));
        $admin = $this->admin();

        $this->actingAs($admin)->post('/api/v1/announcements', $this->payload([
            'image' => UploadedFile::fake()->create('notes.pdf', 10, 'application/pdf'),
        ]), ['Accept' => 'application/json'])->assertUnprocessable()->assertJsonValidationErrors('image');

        $res = $this->actingAs($admin)->post('/api/v1/announcements', $this->payload([
            'image' => UploadedFile::fake()->image('poster.png'),
        ]), ['Accept' => 'application/json'])->assertCreated();

        $this->assertNotNull($res->json('data.image_url'));
        Storage::disk(config('filesystems.default'))->assertExists(Announcement::first()->image_path);
    }
}
