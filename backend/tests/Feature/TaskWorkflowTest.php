<?php

namespace Tests\Feature;

use App\Enums\TaskStatus;
use App\Models\Department;
use App\Models\Notification;
use App\Models\Task;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Concerns\CreatesOrgUsers;
use Tests\TestCase;

class TaskWorkflowTest extends TestCase
{
    use CreatesOrgUsers, RefreshDatabase;

    private function scenario(): array
    {
        $dept = Department::factory()->create();
        $manager = $this->manager($dept);
        $staff = $this->staff($dept);

        return [$dept, $manager, $staff];
    }

    public function test_manager_can_create_and_assign_a_task_and_the_assignee_is_notified(): void
    {
        [$dept, $manager, $staff] = $this->scenario();

        $response = $this->actingAs($manager)->postJson('/api/v1/tasks', [
            'title' => 'Build login screen',
            'description' => 'Flutter desktop login',
            'priority' => 'high',
            'assigned_to' => $staff->id,
        ]);

        $response->assertCreated()
            ->assertJsonPath('data.status', TaskStatus::Assigned->value)
            ->assertJsonPath('data.assignee.id', $staff->id);

        $this->assertDatabaseHas('notifications', [
            'user_id' => $staff->id,
            'type' => 'task_assigned',
        ]);
        $this->assertDatabaseHas('task_status_history', [
            'task_id' => $response->json('data.id'),
            'new_status' => TaskStatus::Assigned->value,
        ]);
    }

    public function test_staff_cannot_create_tasks(): void
    {
        [$dept, $manager, $staff] = $this->scenario();

        $this->actingAs($staff)->postJson('/api/v1/tasks', [
            'title' => 'x',
            'assigned_to' => $staff->id,
        ])->assertForbidden();
    }

    public function test_full_lifecycle_assigned_to_approved(): void
    {
        [$dept, $manager, $staff] = $this->scenario();
        $task = Task::factory()->createdBy($manager)->assignedTo($staff)->create();

        $this->actingAs($staff)->postJson("/api/v1/tasks/{$task->id}/start")
            ->assertOk()->assertJsonPath('data.status', TaskStatus::InProgress->value);

        $this->actingAs($staff)->postJson("/api/v1/tasks/{$task->id}/complete")
            ->assertOk()->assertJsonPath('data.status', TaskStatus::Completed->value);

        $this->assertDatabaseHas('notifications', [
            'user_id' => $manager->id,
            'type' => 'task_completed',
        ]);

        $this->actingAs($manager)->postJson("/api/v1/tasks/{$task->id}/approve")
            ->assertOk()->assertJsonPath('data.status', TaskStatus::Approved->value);

        $this->assertDatabaseHas('notifications', [
            'user_id' => $staff->id,
            'type' => 'task_approved',
        ]);
        // start + complete + approve = 3 recorded transitions
        $this->assertEquals(3, $task->fresh()->statusHistory()->count());
    }

    public function test_invalid_transition_is_rejected(): void
    {
        [$dept, $manager, $staff] = $this->scenario();
        $task = Task::factory()->createdBy($manager)->assignedTo($staff)->create();

        // cannot complete a task that has not been started
        $this->actingAs($staff)->postJson("/api/v1/tasks/{$task->id}/complete")
            ->assertStatus(422);
    }

    public function test_only_assignee_can_start_a_task(): void
    {
        [$dept, $manager, $staff] = $this->scenario();
        $other = $this->staff($dept);
        $task = Task::factory()->createdBy($manager)->assignedTo($staff)->create();

        $this->actingAs($other)->postJson("/api/v1/tasks/{$task->id}/start")->assertForbidden();
    }

    public function test_return_for_revision_requires_a_note_and_records_it(): void
    {
        [$dept, $manager, $staff] = $this->scenario();
        $task = Task::factory()->createdBy($manager)->assignedTo($staff)
            ->status(TaskStatus::Completed)->create(['completed_at' => now()]);

        $this->actingAs($manager)->postJson("/api/v1/tasks/{$task->id}/return")
            ->assertStatus(422); // missing note

        $this->actingAs($manager)->postJson("/api/v1/tasks/{$task->id}/return", [
            'note' => 'Please fix the validation on the email field.',
        ])->assertOk()->assertJsonPath('data.status', TaskStatus::Revision->value);

        $this->assertDatabaseHas('task_comments', [
            'task_id' => $task->id,
            'is_revision_note' => true,
        ]);
        $this->assertDatabaseHas('notifications', [
            'user_id' => $staff->id,
            'type' => 'task_revision',
        ]);
    }

    public function test_staff_cannot_approve_tasks(): void
    {
        [$dept, $manager, $staff] = $this->scenario();
        $task = Task::factory()->createdBy($manager)->assignedTo($staff)
            ->status(TaskStatus::Completed)->create(['completed_at' => now()]);

        $this->actingAs($staff)->postJson("/api/v1/tasks/{$task->id}/approve")->assertForbidden();
    }
}
