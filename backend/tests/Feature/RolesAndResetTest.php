<?php

namespace Tests\Feature;

use App\Models\Department;
use App\Models\Role;
use App\Models\User;
use Illuminate\Auth\Notifications\ResetPassword;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Notification;
use Illuminate\Support\Facades\Password;
use Tests\Concerns\CreatesOrgUsers;
use Tests\TestCase;

class RolesAndResetTest extends TestCase
{
    use CreatesOrgUsers, RefreshDatabase;

    public function test_admin_creates_a_job_title_and_permissions_follow_its_level(): void
    {
        Mail::fake();
        $admin = $this->admin();
        $roleId = $this->actingAs($admin)->postJson('/api/v1/roles', ['label' => 'Accountant', 'level' => 'manager'])
            ->assertCreated()
            ->assertJsonPath('data.level', 'manager')
            ->json('data.id');

        $userId = $this->actingAs($admin)->postJson('/api/v1/users', [
            'name' => 'Asha', 'email' => 'asha@example.com', 'role_id' => $roleId,
            'department_id' => Department::factory()->create()->id,
        ])->assertCreated()
            ->assertJsonPath('data.role', 'manager')
            ->assertJsonPath('data.role_label', 'Accountant')
            ->json('data.id');

        $this->assertTrue(User::find($userId)->isManager());

        // In use: can't delete. Built-ins: can't delete or change level.
        $this->actingAs($admin)->deleteJson("/api/v1/roles/{$roleId}")->assertUnprocessable();
        $staffRole = Role::where('name', 'staff')->first();
        $this->actingAs($admin)->deleteJson("/api/v1/roles/{$staffRole->id}")->assertUnprocessable();
        $this->actingAs($admin)->patchJson("/api/v1/roles/{$staffRole->id}", ['level' => 'admin'])->assertOk();
        $this->assertSame('staff', $staffRole->fresh()->level);
    }

    public function test_only_admins_manage_roles(): void
    {
        $this->actingAs($this->manager())->postJson('/api/v1/roles', ['label' => 'X', 'level' => 'admin'])
            ->assertForbidden();
    }

    public function test_forgot_password_email_links_to_a_working_reset_page(): void
    {
        Notification::fake();
        $user = $this->staff(null, ['email' => 'neema@example.com', 'must_change_password' => true]);

        $this->postJson('/api/v1/auth/password/forgot', ['email' => 'neema@example.com'])->assertOk();

        $url = null;
        Notification::assertSentTo($user, ResetPassword::class, function (ResetPassword $n) use ($user, &$url) {
            $url = $n->toMail($user)->actionUrl;

            return true;
        });
        $this->assertStringContainsString('/reset-password?token=', $url);
        $this->get($url)->assertOk()->assertSee('Choose a new password');

        $token = Password::createToken($user);
        $this->withoutMiddleware(\Illuminate\Foundation\Http\Middleware\ValidateCsrfToken::class)
            ->post('/reset-password', [
                'token' => $token, 'email' => 'neema@example.com',
                'password' => 'BrandNew123!', 'password_confirmation' => 'BrandNew123!',
            ])->assertOk()->assertSee('Password changed');

        $this->postJson('/api/v1/auth/login', ['email' => 'neema@example.com', 'password' => 'BrandNew123!'])
            ->assertOk()->assertJsonPath('user.must_change_password', false);
    }
}
