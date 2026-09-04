<?php

namespace Tests\Feature;

use App\Enums\UserRole;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Concerns\CreatesOrgUsers;
use Tests\TestCase;

class AuthTest extends TestCase
{
    use CreatesOrgUsers, RefreshDatabase;

    public function test_user_can_log_in_with_valid_credentials(): void
    {
        $user = $this->staff(attributes: ['password' => bcrypt('secret123')]);

        $response = $this->postJson('/api/v1/auth/login', [
            'email' => $user->email,
            'password' => 'secret123',
            'device_name' => 'test-desktop',
        ]);

        $response->assertOk()
            ->assertJsonStructure(['token', 'user' => ['id', 'email', 'role']])
            ->assertJsonPath('user.role', UserRole::Staff->value);
    }

    public function test_login_fails_with_wrong_password(): void
    {
        $user = $this->staff(attributes: ['password' => bcrypt('secret123')]);

        $this->postJson('/api/v1/auth/login', [
            'email' => $user->email,
            'password' => 'wrong',
        ])->assertStatus(422);
    }

    public function test_inactive_user_cannot_log_in(): void
    {
        $user = $this->staff(attributes: ['password' => bcrypt('secret123'), 'status' => 'inactive']);

        $this->postJson('/api/v1/auth/login', [
            'email' => $user->email,
            'password' => 'secret123',
        ])->assertStatus(422);
    }

    public function test_me_returns_the_authenticated_user(): void
    {
        $user = $this->manager();

        $this->actingAs($user)->getJson('/api/v1/me')
            ->assertOk()
            ->assertJsonPath('data.id', $user->id)
            ->assertJsonPath('data.role', UserRole::Manager->value);
    }

    public function test_guest_cannot_access_protected_routes(): void
    {
        $this->getJson('/api/v1/tasks')->assertUnauthorized();
    }

    public function test_deactivated_token_is_rejected_by_active_middleware(): void
    {
        $user = $this->staff();
        $user->update(['status' => 'inactive']);

        $this->actingAs($user)->getJson('/api/v1/me')->assertStatus(403);
    }
}
