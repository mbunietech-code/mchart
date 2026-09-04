<?php

namespace Tests\Feature;

use App\Enums\UserRole;
use App\Models\Department;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Concerns\CreatesOrgUsers;
use Tests\TestCase;

class UserManagementTest extends TestCase
{
    use CreatesOrgUsers, RefreshDatabase;

    public function test_admin_can_create_a_user(): void
    {
        $dept = Department::factory()->create();

        $this->actingAs($this->admin())->postJson('/api/v1/users', [
            'name' => 'New Dev',
            'email' => 'newdev@mbunietech.com',
            'password' => 'Password123',
            'password_confirmation' => 'Password123',
            'role' => UserRole::Staff->value,
            'department_id' => $dept->id,
        ])->assertCreated()->assertJsonPath('data.role', UserRole::Staff->value);

        $this->assertDatabaseHas('users', ['email' => 'newdev@mbunietech.com']);
    }

    public function test_manager_cannot_create_a_user(): void
    {
        $this->actingAs($this->manager())->postJson('/api/v1/users', [
            'name' => 'x', 'email' => 'x@x.com', 'password' => 'Password123',
            'password_confirmation' => 'Password123', 'role' => 'staff',
        ])->assertForbidden();
    }

    public function test_deactivating_a_user_revokes_their_tokens(): void
    {
        $admin = $this->admin();
        $victim = $this->staff();
        $victim->createToken('x');

        $this->actingAs($admin)->deleteJson("/api/v1/users/{$victim->id}")->assertOk();

        $this->assertSame('inactive', $victim->fresh()->status);
        $this->assertSame(0, $victim->tokens()->count());
    }

    public function test_admin_only_routes_reject_staff(): void
    {
        $this->actingAs($this->staff())->postJson('/api/v1/departments', ['name' => 'Nope'])
            ->assertForbidden();
    }
}
