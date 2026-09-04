<?php

namespace Database\Factories;

use App\Enums\UserRole;
use App\Models\Department;
use App\Models\Role;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

/**
 * @extends Factory<User>
 */
class UserFactory extends Factory
{
    protected static ?string $password;

    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'name' => fake()->name(),
            'email' => fake()->unique()->safeEmail(),
            'phone' => fake()->optional()->numerify('+2557########'),
            'email_verified_at' => now(),
            'password' => static::$password ??= Hash::make('password'),
            'remember_token' => Str::random(10),
            'role_id' => fn () => Role::where('name', UserRole::Staff->value)->value('id')
                ?? Role::factory()->create(['name' => UserRole::Staff->value])->id,
            'department_id' => null,
            'status' => 'active',
        ];
    }

    public function unverified(): static
    {
        return $this->state(fn (array $attributes) => ['email_verified_at' => null]);
    }

    public function role(UserRole $role): static
    {
        return $this->state(fn () => [
            'role_id' => Role::where('name', $role->value)->value('id')
                ?? Role::factory()->create(['name' => $role->value])->id,
        ]);
    }

    public function admin(): static
    {
        return $this->role(UserRole::Admin);
    }

    public function manager(): static
    {
        return $this->role(UserRole::Manager);
    }

    public function staff(): static
    {
        return $this->role(UserRole::Staff);
    }

    public function inDepartment(Department|int $department): static
    {
        return $this->state(fn () => [
            'department_id' => $department instanceof Department ? $department->id : $department,
        ]);
    }

    public function inactive(): static
    {
        return $this->state(fn () => ['status' => 'inactive']);
    }
}
