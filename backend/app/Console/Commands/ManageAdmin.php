<?php

namespace App\Console\Commands;

use App\Enums\UserRole;
use App\Models\Role;
use App\Models\User;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rules\Password;
use Illuminate\Support\Facades\Validator;

/**
 * Create or update an admin account without needing tinker (some shared hosts
 * disable shell_exec, which psysh requires).
 *
 *   php artisan mchart:admin admin@example.com --name="Jane" --password=Secret123
 *   php artisan mchart:admin admin@example.com --password=NewSecret123
 */
class ManageAdmin extends Command
{
    protected $signature = 'mchart:admin
        {email : The admin email address}
        {--name= : Display name (defaults to the part before @ on create)}
        {--password= : Password; prompted for if omitted}
        {--role=admin : admin|manager|staff}';

    protected $description = 'Create or update an MChart user (defaults to the admin role)';

    public function handle(): int
    {
        $email = strtolower(trim($this->argument('email')));
        $roleName = $this->option('role');
        $password = $this->option('password') ?: $this->secret('New password');

        $roleId = Role::where('name', $roleName)->value('id');
        if (! $roleId) {
            $this->error("Role \"{$roleName}\" not found. Run `php artisan db:seed --class=RoleSeeder` first.");
            return self::FAILURE;
        }

        $validator = Validator::make(
            ['email' => $email, 'password' => $password],
            ['email' => ['required', 'email'], 'password' => ['required', Password::min(8)]],
        );
        if ($validator->fails()) {
            foreach ($validator->errors()->all() as $message) {
                $this->error($message);
            }
            return self::FAILURE;
        }

        $existing = User::where('email', $email)->first();
        $name = $this->option('name')
            ?: ($existing->name ?? ucfirst(explode('@', $email)[0]));

        $user = User::updateOrCreate(
            ['email' => $email],
            [
                'name' => $name,
                'password' => Hash::make($password),
                'role_id' => $roleId,
                'status' => 'active',
                'email_verified_at' => now(),
            ],
        );

        $this->info(sprintf(
            '%s %s (%s) as %s.',
            $user->wasRecentlyCreated ? 'Created' : 'Updated',
            $user->name,
            $user->email,
            UserRole::from($roleName)->label(),
        ));

        return self::SUCCESS;
    }
}
