<?php

namespace Database\Seeders;

use App\Enums\ConversationType;
use App\Enums\TaskPriority;
use App\Enums\TaskStatus;
use App\Models\Conversation;
use App\Models\Department;
use App\Models\Role;
use App\Models\Task;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        $this->call([
            RoleSeeder::class,
            DepartmentSeeder::class,
        ]);

        $roles = Role::pluck('id', 'name');
        $programming = Department::where('name', 'Programming')->first();
        $design = Department::where('name', 'Design')->first();

        $admin = User::updateOrCreate(
            ['email' => 'admin@mbunietech.com'],
            [
                'name' => 'MbuniTech Admin',
                'password' => Hash::make('password'),
                'role_id' => $roles['admin'],
                'department_id' => null,
                'status' => 'active',
                'email_verified_at' => now(),
            ],
        );

        if (! app()->environment('production')) {
            $this->seedDemoData($roles, $programming, $design, $admin);
        }
    }

    private function seedDemoData($roles, Department $programming, Department $design, User $admin): void
    {
        $manager = User::updateOrCreate(
            ['email' => 'manager@mbunietech.com'],
            [
                'name' => 'Grace Manager',
                'password' => Hash::make('password'),
                'role_id' => $roles['manager'],
                'department_id' => $programming->id,
                'status' => 'active',
                'email_verified_at' => now(),
            ],
        );

        $devs = collect(['Amani Dev', 'Baraka Dev', 'Neema Dev'])->map(function ($name, $i) use ($roles, $programming) {
            return User::updateOrCreate(
                ['email' => 'dev'.($i + 1).'@mbunietech.com'],
                [
                    'name' => $name,
                    'password' => Hash::make('password'),
                    'role_id' => $roles['staff'],
                    'department_id' => $programming->id,
                    'status' => 'active',
                    'email_verified_at' => now(),
                ],
            );
        });

        // A programming channel with everyone in it.
        $channel = Conversation::firstOrCreate(
            ['type' => ConversationType::Channel, 'name' => 'Programming'],
            ['department_id' => $programming->id, 'created_by' => $manager->id],
        );
        foreach ([$manager, ...$devs] as $member) {
            $channel->participants()->firstOrCreate(['user_id' => $member->id], ['joined_at' => now()]);
        }

        // A few tasks across the lifecycle.
        if (Task::count() === 0) {
            Task::factory()->createdBy($manager)->assignedTo($devs[0])->create([
                'title' => 'Build login screen',
                'priority' => TaskPriority::High,
                'status' => TaskStatus::InProgress,
                'started_at' => now()->subDay(),
                'deadline' => now()->addDays(3),
            ]);

            Task::factory()->createdBy($manager)->assignedTo($devs[1])->create([
                'title' => 'Set up CI pipeline',
                'priority' => TaskPriority::Medium,
                'status' => TaskStatus::Completed,
                'started_at' => now()->subDays(3),
                'completed_at' => now()->subHours(4),
                'deadline' => now()->subDay(),
            ]);

            Task::factory()->createdBy($manager)->assignedTo($devs[2])->create([
                'title' => 'Draft API documentation',
                'priority' => TaskPriority::Low,
                'status' => TaskStatus::Assigned,
            ]);
        }
    }
}
