<?php

namespace Tests\Feature;

use App\Models\Department;
use App\Models\Task;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Concerns\CreatesOrgUsers;
use Tests\TestCase;

class TaskVisibilityTest extends TestCase
{
    use CreatesOrgUsers, RefreshDatabase;

    public function test_staff_only_sees_their_own_tasks(): void
    {
        $dept = Department::factory()->create();
        $manager = $this->manager($dept);
        $me = $this->staff($dept);
        $peer = $this->staff($dept);

        Task::factory()->createdBy($manager)->assignedTo($me)->create();
        Task::factory()->createdBy($manager)->assignedTo($peer)->create();

        $this->actingAs($me)->getJson('/api/v1/tasks')
            ->assertOk()
            ->assertJsonCount(1, 'data');
    }

    public function test_manager_sees_department_tasks_but_not_other_departments(): void
    {
        $deptA = Department::factory()->create();
        $deptB = Department::factory()->create();
        $managerA = $this->manager($deptA);
        $staffA = $this->staff($deptA);
        $staffB = $this->staff($deptB);
        $managerB = $this->manager($deptB);

        Task::factory()->createdBy($managerA)->assignedTo($staffA)->create();
        Task::factory()->createdBy($managerB)->assignedTo($staffB)->create();

        $this->actingAs($managerA)->getJson('/api/v1/tasks')
            ->assertOk()
            ->assertJsonCount(1, 'data');
    }

    public function test_admin_sees_all_tasks(): void
    {
        $deptA = Department::factory()->create();
        $deptB = Department::factory()->create();
        Task::factory()->createdBy($this->manager($deptA))->assignedTo($this->staff($deptA))->create();
        Task::factory()->createdBy($this->manager($deptB))->assignedTo($this->staff($deptB))->create();

        $this->actingAs($this->admin())->getJson('/api/v1/tasks')
            ->assertOk()
            ->assertJsonCount(2, 'data');
    }

    public function test_staff_cannot_view_a_peers_task_detail(): void
    {
        $dept = Department::factory()->create();
        $manager = $this->manager($dept);
        $me = $this->staff($dept);
        $peer = $this->staff($dept);
        $task = Task::factory()->createdBy($manager)->assignedTo($peer)->create();

        $this->actingAs($me)->getJson("/api/v1/tasks/{$task->id}")->assertForbidden();
    }
}
