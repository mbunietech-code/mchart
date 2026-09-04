<?php

namespace Tests\Feature;

use App\Enums\TaskStatus;
use App\Models\Department;
use App\Models\Task;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Concerns\CreatesOrgUsers;
use Tests\TestCase;

class DashboardTest extends TestCase
{
    use CreatesOrgUsers, RefreshDatabase;

    public function test_summary_returns_counts_scoped_to_the_manager_department(): void
    {
        $dept = Department::factory()->create();
        $manager = $this->manager($dept);
        $staff = $this->staff($dept);

        Task::factory()->createdBy($manager)->assignedTo($staff)->status(TaskStatus::Assigned)->create();
        Task::factory()->createdBy($manager)->assignedTo($staff)->status(TaskStatus::InProgress)->create();
        Task::factory()->createdBy($manager)->assignedTo($staff)->status(TaskStatus::Approved)
            ->create(['approved_at' => now()]);
        Task::factory()->createdBy($manager)->assignedTo($staff)->status(TaskStatus::InProgress)
            ->create(['deadline' => now()->subDay()]);

        $response = $this->actingAs($manager)->getJson('/api/v1/dashboard/summary')->assertOk();

        $response->assertJsonPath('counts.assigned', 1)
            ->assertJsonPath('counts.in_progress', 2)
            ->assertJsonPath('counts.approved', 1)
            ->assertJsonPath('counts.overdue', 1);

        $this->assertSame(4, $response->json('counts.open') + $response->json('counts.approved'));
    }

    public function test_activity_feed_lists_recent_status_changes(): void
    {
        $dept = Department::factory()->create();
        $manager = $this->manager($dept);
        $staff = $this->staff($dept);
        $task = Task::factory()->createdBy($manager)->assignedTo($staff)->create();

        $this->actingAs($staff)->postJson("/api/v1/tasks/{$task->id}/start")->assertOk();

        $this->actingAs($manager)->getJson('/api/v1/dashboard/activity')
            ->assertOk()
            ->assertJsonPath('data.0.new_status', TaskStatus::InProgress->value);
    }
}
