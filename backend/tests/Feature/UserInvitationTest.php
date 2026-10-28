<?php

namespace Tests\Feature;

use App\Mail\UserInvitation;
use App\Models\Department;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Mail;
use Tests\Concerns\CreatesOrgUsers;
use Tests\TestCase;

class UserInvitationTest extends TestCase
{
    use CreatesOrgUsers, RefreshDatabase;

    private function invite(array $overrides = []): \Illuminate\Testing\TestResponse
    {
        return $this->actingAs($this->admin(['name' => 'Boss']))->postJson('/api/v1/users', array_merge([
            'name' => 'Neema',
            'email' => 'neema@example.com',
            'role' => 'staff',
            'department_id' => Department::factory()->create()->id,
        ], $overrides));
    }

    public function test_admin_invite_without_password_generates_one_and_emails_it(): void
    {
        Mail::fake();

        $res = $this->invite()->assertCreated()
            ->assertJsonPath('data.must_change_password', true);
        $temporary = $res->json('temporary_password');
        $this->assertNotEmpty($temporary);

        Mail::assertSent(UserInvitation::class, function (UserInvitation $mail) use ($temporary) {
            $html = $mail->render();

            return $mail->hasTo('neema@example.com')
                && $mail->temporaryPassword === $temporary
                && str_contains($html, 'neema@example.com')
                && str_contains($html, $temporary)
                && $mail->invitedBy === 'Boss';
        });

        // The temporary password works for signing in.
        $this->postJson('/api/v1/auth/login', ['email' => 'neema@example.com', 'password' => $temporary])
            ->assertOk()
            ->assertJsonPath('user.must_change_password', true);
    }

    public function test_temporary_password_blocks_everything_until_changed(): void
    {
        Mail::fake();
        $temporary = $this->invite()->json('temporary_password');
        $token = $this->postJson('/api/v1/auth/login', [
            'email' => 'neema@example.com', 'password' => $temporary,
        ])->json('token');
        $auth = ['Authorization' => "Bearer {$token}"];
        $this->app['auth']->forgetGuards(); // drop the admin from invite()

        $this->getJson('/api/v1/me', $auth)->assertOk()->assertJsonPath('data.email', 'neema@example.com');
        $this->getJson('/api/v1/conversations', $auth)
            ->assertForbidden()
            ->assertJsonPath('code', 'password_change_required');

        $this->postJson('/api/v1/auth/password/change', [
            'current_password' => 'wrong-one',
            'password' => 'MyOwnPass123!',
            'password_confirmation' => 'MyOwnPass123!',
        ], $auth)->assertUnprocessable()->assertJsonValidationErrors('current_password');

        $this->postJson('/api/v1/auth/password/change', [
            'current_password' => $temporary,
            'password' => 'MyOwnPass123!',
            'password_confirmation' => 'MyOwnPass123!',
        ], $auth)->assertOk()->assertJsonPath('data.must_change_password', false);

        $this->app['auth']->forgetGuards();
        $this->getJson('/api/v1/conversations', $auth)->assertOk();

        // Old temporary password no longer works.
        $this->postJson('/api/v1/auth/login', ['email' => 'neema@example.com', 'password' => $temporary])
            ->assertUnprocessable();
    }

    public function test_admin_supplied_initial_password_is_also_temporary(): void
    {
        Mail::fake();
        $this->invite(['password' => 'Initial123!', 'password_confirmation' => 'Initial123!'])
            ->assertCreated()
            ->assertJsonPath('data.must_change_password', true)
            ->assertJsonPath('temporary_password', 'Initial123!');
        Mail::assertSent(UserInvitation::class);
    }

    public function test_admin_resetting_someone_elses_password_forces_a_change(): void
    {
        $admin = $this->admin();
        $user = $this->staff();

        $this->actingAs($admin)->patchJson("/api/v1/users/{$user->id}", [
            'password' => 'Reset1234!', 'password_confirmation' => 'Reset1234!',
        ])->assertOk();

        $this->assertTrue($user->fresh()->must_change_password);
    }

    public function test_user_still_created_when_mail_fails(): void
    {
        Mail::shouldReceive('to')->andThrow(new \RuntimeException('SMTP down'));

        $this->invite()->assertCreated()->assertJsonPath('invitation_sent', false);
        $this->assertDatabaseHas('users', ['email' => 'neema@example.com']);
    }

    public function test_unused_invite_can_be_deleted_and_email_reused(): void
    {
        Mail::fake();
        $id = $this->invite()->json('data.id');
        $admin = User::where('email', '!=', 'neema@example.com')->first();

        $this->actingAs($admin)->deleteJson("/api/v1/users/{$id}/permanent")->assertOk();
        $this->assertDatabaseMissing('users', ['email' => 'neema@example.com']);

        $this->invite()->assertCreated(); // email is free again
    }

    public function test_user_with_history_cannot_be_deleted_and_admin_cannot_delete_self(): void
    {
        $dept = \App\Models\Department::factory()->create();
        $admin = $this->admin();
        [$a, $b] = [$this->staff($dept), $this->staff($dept)];
        $c = \App\Models\Conversation::factory()->direct()->withParticipants([$a, $b])->create();
        $this->actingAs($a)->postJson("/api/v1/conversations/{$c->id}/messages", ['body' => 'hi'])->assertCreated();

        $this->actingAs($admin)->deleteJson("/api/v1/users/{$a->id}/permanent")
            ->assertUnprocessable()
            ->assertJsonPath('code', 'user_has_history');
        $this->assertDatabaseHas('users', ['id' => $a->id]);

        $this->actingAs($admin)->deleteJson("/api/v1/users/{$admin->id}/permanent")->assertUnprocessable();
        $this->actingAs($b)->deleteJson("/api/v1/users/{$b->id}/permanent")->assertForbidden();
    }

    public function test_generated_passwords_are_strong_and_differ(): void
    {
        $a = \App\Http\Controllers\Api\V1\UserController::temporaryPassword();
        $b = \App\Http\Controllers\Api\V1\UserController::temporaryPassword();

        $this->assertNotSame($a, $b);
        $this->assertMatchesRegularExpression('/^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)(?=.*[@#%*!]).{11}$/', $a);
        $this->assertSame(0, User::count());
    }
}
